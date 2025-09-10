import SwiftUI
import Supabase

struct SkillsGiftsScreen: View {
    @Binding var currentStep: OnboardingStep
    @State private var skillsText = ""
    @State private var skills: [String] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var animateElements = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation {
                            currentStep = .profileCreation  // Go back to profile creation
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 20) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 20)
                                .scaleEffect(animateElements ? 1.0 : 0.8)
                                .opacity(animateElements ? 1.0 : 0.0)
                            
                            VStack(spacing: 12) {
                                Text("Give a gift to the world")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("What skills and experiences can you share?")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .offset(y: animateElements ? 0 : 20)
                            .opacity(animateElements ? 1.0 : 0.0)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Skills & Gifts")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                ZStack(alignment: .topLeading) {
                                    if skillsText.isEmpty {
                                        Text("kiteboarding, host, chef, photographer, musician, yoga teacher...")
                                            .font(.system(size: 16, weight: .regular, design: .rounded))
                                            .foregroundColor(.white.opacity(0.3))
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 16)
                                    }
                                    
                                    TextEditor(text: $skillsText)
                                        .font(.system(size: 16, weight: .regular, design: .rounded))
                                        .foregroundColor(.white)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                .frame(minHeight: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.08))
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.5),
                                                            Color.white.opacity(0.1)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .padding(.horizontal, 32)
                            .offset(y: animateElements ? 0 : 30)
                            .opacity(animateElements ? 1.0 : 0.0)
                            
                            if !skills.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Your Tags")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 32)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(skills, id: \.self) { skill in
                                                SkillTag(skill: skill) {
                                                    withAnimation {
                                                        skills.removeAll { $0 == skill }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 32)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            VStack(spacing: 16) {
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.red)
                                }
                                
                                Button(action: completeSetup) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Complete Setup")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                                .padding(.horizontal, 32)
                                .disabled(isLoading)
                            }
                            .offset(y: animateElements ? 0 : 40)
                            .opacity(animateElements ? 1.0 : 0.0)
                        }
                        
                        VStack(spacing: 20) {
                            Text("Examples of gifts you can share:")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ExampleRow(icon: "figure.surfing", text: "Teach kiteboarding or surfing")
                                ExampleRow(icon: "fork.knife", text: "Cook a traditional meal")
                                ExampleRow(icon: "camera.fill", text: "Offer photography sessions")
                                ExampleRow(icon: "guitars.fill", text: "Share music or perform")
                                ExampleRow(icon: "map.fill", text: "Guide local tours")
                                ExampleRow(icon: "paintbrush.fill", text: "Create art together")
                            }
                            .padding(.horizontal, 40)
                        }
                        .opacity(animateElements ? 0.6 : 0.0)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateElements = true
            }
        }
        .onChange(of: skillsText) { newValue in
            parseSkills(from: newValue)
        }
    }
    
    private func parseSkills(from text: String) {
        let separators = CharacterSet(charactersIn: ",\n")
        skills = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func completeSetup() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let session = try await SupabaseManager.shared.auth.session
                let user = session.user
                
                struct ProfileSkillsUpdate: Codable {
                    let skills: [String]?
                    let updated_at: String
                }
                
                let update = ProfileSkillsUpdate(
                    skills: skills.isEmpty ? nil : skills,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                try await SupabaseManager.shared.database
                    .from("profiles")
                    .update(update)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    withAnimation {
                        currentStep = .photoAnalysis
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save skills. Please try again."
                    isLoading = false
                }
            }
        }
    }
}

struct SkillTag: View {
    let skill: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(skill)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.4),
                            Color.pink.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ExampleRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}