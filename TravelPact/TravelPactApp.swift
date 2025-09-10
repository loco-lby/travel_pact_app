import SwiftUI
import Supabase
import Auth
import os.log

// Helper struct for profile decoding
private struct ProfileResponse: Codable {
    let id: String
    let name: String?
    let onboarding_completed: Bool?
    let created_at: String?
}

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var hasCompletedProfile = false
    
    func checkAuthStatus() {
        Task {
            do {
                let session = try await SupabaseManager.shared.auth.session
                let userId = session.user.id
                
                // Check if profile exists
                let profileExists = await checkProfileExists(userId: userId)
                
                await MainActor.run {
                    isAuthenticated = true
                    hasCompletedProfile = profileExists
                    isCheckingAuth = false
                }
            } catch {
                await MainActor.run {
                    isAuthenticated = false
                    hasCompletedProfile = false
                    isCheckingAuth = false
                }
            }
        }
    }
    
    private func checkProfileExists(userId: UUID) async -> Bool {
        do {
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select("id, name, onboarding_completed, created_at")
                .eq("id", value: userId.uuidString)
                .execute()
            
            // Debug: Print raw response
            #if DEBUG
            if let responseString = String(data: response.data, encoding: .utf8) {
                print("📊 Raw profile query response: \(responseString)")
            }
            #endif
            
            // Check if response is empty array
            let responseString = String(data: response.data, encoding: .utf8) ?? ""
            if responseString == "[]" {
                #if DEBUG
                print("⚠️ Empty profile response - no profile exists")
                #endif
                return false
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            if let profiles = try? decoder.decode([ProfileResponse].self, from: response.data),
               !profiles.isEmpty,
               let profile = profiles.first {
                
                // Check if onboarding is completed
                let onboardingCompleted = profile.onboarding_completed ?? false
                
                #if DEBUG
                print("📊 Profile found - Name: \(profile.name ?? "nil"), Onboarding completed: \(onboardingCompleted)")
                #endif
                
                // Only consider profile complete if onboarding_completed is true
                if onboardingCompleted {
                    print("✅ Found profile with completed onboarding")
                    return true
                } else {
                    print("⚠️ Profile exists but onboarding not completed")
                    return false
                }
            }
            
            #if DEBUG
            print("⚠️ No valid profile found for user: \(userId)")
            #endif
            return false
            
        } catch {
            #if DEBUG
            print("❌ Error checking profile: \(error)")
            #endif
            return false
        }
    }
    
    func signOut() {
        Task {
            do {
                try await SupabaseManager.shared.signOut()
                await MainActor.run {
                    isAuthenticated = false
                }
            } catch {
                print("Error signing out: \(error)")
            }
        }
    }
}

@main
struct TravelPactApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var locationManager = LocationPrivacyManager.shared
    
    init() {
        // Initialize the photo analysis manager early to check for incomplete analysis
        _ = BackgroundPhotoAnalysisManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isCheckingAuth {
                    LaunchScreen()
                } else if authManager.isAuthenticated && authManager.hasCompletedProfile {
                    GlobeView()
                        .environmentObject(authManager)
                } else {
                    OnboardingCoordinator()
                        .environmentObject(authManager)
                }
            }
            .onAppear {
                authManager.checkAuthStatus()
            }
        }
    }
}

struct LaunchScreen: View {
    @State private var animateLogo = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.3), radius: 10)
                    .scaleEffect(animateLogo ? 1.0 : 0.8)
                    .opacity(animateLogo ? 1.0 : 0.0)
                
                Text("TravelPact")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.top, 20)
                    .opacity(animateLogo ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateLogo = true
            }
        }
    }
}