import SwiftUI

struct ProfileMenuView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var userName: String = ""
    @State private var userPhone: String = ""
    @State private var showingLogoutAlert = false
    @State private var isLoadingProfile = true
    
    var body: some View {
        VStack {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            // Menu container
            VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        // Profile icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.8),
                                            Color.purple.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.2), radius: 10)
                        
                        // User info
                        VStack(spacing: 4) {
                            if isLoadingProfile {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Text(userName.isEmpty ? "TravelPact User" : userName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                if !userPhone.isEmpty {
                                    Text(userPhone)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Menu items
                    VStack(spacing: 0) {
                        // Settings
                        MenuButton(
                            icon: "gearshape.fill",
                            title: "Settings",
                            action: {
                                // TODO: Navigate to settings
                                dismiss()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)
                        
                        // Privacy
                        MenuButton(
                            icon: "lock.fill",
                            title: "Privacy",
                            action: {
                                // TODO: Navigate to privacy settings
                                dismiss()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)
                        
                        // Help
                        MenuButton(
                            icon: "questionmark.circle.fill",
                            title: "Help",
                            action: {
                                // TODO: Navigate to help
                                dismiss()
                            }
                        )
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.top, 8)
                        
                        // Sign Out
                        MenuButton(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Sign Out",
                            color: .red,
                            action: {
                                showingLogoutAlert = true
                            }
                        )
                        .padding(.bottom, 8)
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .shadow(color: .black.opacity(0.3), radius: 20)
            
            Spacer()
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    private func loadUserProfile() {
        Task {
            do {
                let session = try await SupabaseManager.shared.auth.session
                let userId = session.user.id
                
                let response = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("name, phone")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                
                if let profile = try? JSONDecoder().decode(ProfileData.self, from: response.data) {
                    await MainActor.run {
                        userName = profile.name ?? ""
                        userPhone = profile.phone ?? ""
                        isLoadingProfile = false
                    }
                }
            } catch {
                print("Error loading profile: \(error)")
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }
}

struct MenuButton: View {
    let icon: String
    let title: String
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color.opacity(0.8))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ProfileData: Codable {
    let name: String?
    let phone: String?
}