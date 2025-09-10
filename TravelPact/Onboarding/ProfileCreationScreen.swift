import SwiftUI
import PhotosUI
import Supabase
import Storage
import Auth
import MapKit

struct ProfileCreationScreen: View {
    @Binding var currentStep: OnboardingStep
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var userName = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showActionSheet = false
    
    var body: some View {
        ZStack {
            // Globe background with blur overlay
            OnboardingGlobeBackground(showWaypoints: false, waypoints: [])
                .ignoresSafeArea()
            
            // Blurred overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .background(
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation {
                            currentStep = .phoneAuth
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: skipProfile) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                ScrollView {
                    VStack(spacing: 40) {
                        VStack(spacing: 16) {
                            Text("Create Your Profile")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Let's get to know you better")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 32) {
                            Button(action: {
                                showActionSheet = true
                            }) {
                                ZStack {
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 140)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.8),
                                                                Color.white.opacity(0.2)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                            )
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .background(
                                                    Circle()
                                                        .fill(.ultraThinMaterial)
                                                )
                                                .frame(width: 140, height: 140)
                                            
                                            VStack(spacing: 8) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.white.opacity(0.7))
                                                
                                                Text("Add Photo")
                                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    
                                    if selectedImage != nil {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                            )
                                            .offset(x: 50, y: 50)
                                    }
                                }
                            }
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                            
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Name")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    LiquidGlassTextField(
                                        placeholder: "Enter your name",
                                        text: $userName
                                    )
                                }
                                
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 32)
                            
                            Button(action: saveProfile) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Continue")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                            .padding(.horizontal, 32)
                            .disabled(userName.isEmpty || isLoading)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showActionSheet) {
            Button("Camera") {
                imagePickerSourceType = .camera
                showingImagePicker = true
            }
            Button("Photo Library") {
                imagePickerSourceType = .photoLibrary
                showingImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                selectedImage: $selectedImage,
                sourceType: imagePickerSourceType
            )
        }
    }
    
    private func saveProfile() {
        guard !userName.isEmpty else { 
            errorMessage = "Please enter your name"
            return 
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Get current session
                let session = try await SupabaseManager.shared.auth.session
                let user = session.user
                
                #if DEBUG
                print("📝 Saving profile for user: \(userName)")
                #endif
                
                var photoURL: String? = nil
                
                // Upload photo if selected
                if let image = selectedImage,
                   let imageData = image.jpegData(compressionQuality: 0.7) {
                    
                    let fileName = "\(user.id)/profile.jpg"
                    
                    do {
                        _ = try await SupabaseManager.shared.storage
                            .from("avatars")  // Changed from "profiles" to "avatars" - common bucket name
                            .upload(
                                fileName,
                                data: imageData
                            )
                        
                        let signedURL = try await SupabaseManager.shared.storage
                            .from("avatars")
                            .createSignedURL(path: fileName, expiresIn: 60 * 60 * 24 * 365)
                        photoURL = signedURL.absoluteString
                        
                        #if DEBUG
                        print("📸 Photo uploaded")
                        #endif
                    } catch {
                        // Continue without photo - not critical
                        #if DEBUG
                        print("⚠️ Photo upload skipped")
                        #endif
                    }
                }
                
                // Create profile data
                struct ProfileInsert: Codable {
                    let id: String
                    let phone: String?
                    let name: String
                    let photo_url: String?
                    let onboarding_completed: Bool
                    let created_at: String
                    let updated_at: String
                }
                
                let profile = ProfileInsert(
                    id: user.id.uuidString,
                    phone: user.phone,
                    name: userName,
                    photo_url: photoURL,
                    onboarding_completed: false,  // Will be set to true at the end of onboarding
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                print("💾 Saving profile to database...")
                
                // Use upsert to handle both insert and update cases
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .upsert(profile)
                    .execute()
                
                print("✅ Profile saved successfully for \(profile.name)")
                
                // Navigate to photo analysis
                // Don't set hasCompletedProfile yet - onboarding isn't done
                await MainActor.run {
                    withAnimation {
                        currentStep = .photoAnalysis  // Skip location and skills steps
                    }
                    isLoading = false
                }
            } catch {
                #if DEBUG
                print("❌ Profile save error: \(error.localizedDescription)")
                #endif
                
                await MainActor.run {
                    // More specific error messages
                    if error.localizedDescription.contains("storage") {
                        errorMessage = "Photo upload failed. Continue without photo?"
                    } else if error.localizedDescription.contains("profiles") || error.localizedDescription.contains("relation") {
                        errorMessage = "Database error. Please ensure profiles table exists in Supabase."
                    } else {
                        errorMessage = "Failed to save profile. Please try again."
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func skipProfile() {
        // Save minimal profile with just the name if provided
        if !userName.isEmpty {
            Task {
                do {
                    let session = try await SupabaseManager.shared.auth.session
                    let user = session.user
                    
                    struct MinimalProfile: Codable {
                        let id: String
                        let name: String
                        let phone: String?
                        let created_at: String
                        let updated_at: String
                    }
                    
                    let profile = MinimalProfile(
                        id: user.id.uuidString,
                        name: userName.isEmpty ? "User" : userName,
                        phone: user.phone,
                        created_at: ISO8601DateFormatter().string(from: Date()),
                        updated_at: ISO8601DateFormatter().string(from: Date())
                    )
                    
                    try await SupabaseManager.shared.database
                        .from("profiles")
                        .upsert(profile)
                        .execute()
                } catch {
                    print("Skip profile save error: \(error)")
                }
            }
        }
        
        // Navigate to next screen
        withAnimation {
            currentStep = .photoAnalysis  // Skip location and skills steps
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.selectedImage = image
            } else if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}