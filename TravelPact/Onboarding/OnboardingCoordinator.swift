import SwiftUI
import Supabase

enum OnboardingStep {
    case welcome
    case phoneAuth
    case profileCreation
    // case locationSetting  // Removed - can be part of profile or done later
    // case skillsGifts      // Removed - optional, can be done in settings
    case photoAnalysis
    case complete
}

struct OnboardingCoordinator: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            switch currentStep {
            case .welcome:
                WelcomeScreen(currentStep: $currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                
            case .phoneAuth:
                PhoneAuthScreen(currentStep: $currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                
            case .profileCreation:
                ProfileCreationScreen(currentStep: $currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                
            // Removed from flow - can be integrated into profile or settings
            // case .locationSetting:
            //     LocationSettingScreen(currentStep: $currentStep)
            //         .transition(.asymmetric(
            //             insertion: .move(edge: .trailing),
            //             removal: .move(edge: .leading)
            //         ))
                
            // case .skillsGifts:
            //     SkillsGiftsScreen(currentStep: $currentStep)
            //         .transition(.asymmetric(
            //             insertion: .move(edge: .trailing),
            //             removal: .move(edge: .leading)
            //         ))
                
            case .photoAnalysis:
                PhotoAnalysisViewWrapper(currentStep: $currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                
            case .complete:
                OnboardingCompleteScreen(showMainApp: $showMainApp)
                    .environmentObject(authManager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
        .fullScreenCover(isPresented: $showMainApp) {
            MainTabView()
                .environmentObject(authManager)
        }
        .onAppear {
            // Don't auto-skip - let users go through the flow naturally
            // The onboarding should start from welcome screen
        }
    }
}

struct OnboardingCompleteScreen: View {
    @Binding var showMainApp: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var animateElements = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.6),
                                        Color.blue.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .white.opacity(0.5), radius: 20)
                    }
                    .scaleEffect(animateElements ? 1.0 : 0.5)
                    .opacity(animateElements ? 1.0 : 0.0)
                    
                    VStack(spacing: 16) {
                        Text("Welcome to TravelPact!")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your journey of authentic connections begins now")
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .offset(y: animateElements ? 0 : 20)
                    .opacity(animateElements ? 1.0 : 0.0)
                }
                
                Spacer()
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            CompletionIcon(
                                icon: "person.crop.circle.badge.checkmark",
                                label: "Profile Ready",
                                color: .green
                            )
                            
                            CompletionIcon(
                                icon: "location.circle.fill",
                                label: "Location Set",
                                color: .blue
                            )
                            
                            CompletionIcon(
                                icon: "sparkles",
                                label: "Skills Added",
                                color: .purple
                            )
                        }
                    }
                    .offset(y: animateElements ? 0 : 30)
                    .opacity(animateElements ? 1.0 : 0.0)
                    
                    Button(action: {
                        // Mark profile as complete and show main app
                        authManager.checkAuthStatus()
                        showMainApp = true
                    }) {
                        HStack {
                            Text("Start Exploring")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                    .padding(.horizontal, 32)
                    .offset(y: animateElements ? 0 : 40)
                    .opacity(animateElements ? 1.0 : 0.0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateElements = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
            }
        }
    }
}

struct CompletionIcon: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    ConfettiPieceView(piece: piece)
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
    }
    
    func createConfetti(in size: CGSize) {
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: [Color.blue, Color.purple, Color.pink, Color.yellow, Color.green].randomElement()!,
                size: CGFloat.random(in: 4...8),
                velocity: CGFloat.random(in: 100...400)
            )
            confettiPieces.append(piece)
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let velocity: CGFloat
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var yOffset: CGFloat = 0
    @State private var rotation = Double.random(in: 0...360)
    
    var body: some View {
        Circle()
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size)
            .position(x: piece.x, y: piece.y + yOffset)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: Double.random(in: 2...4))) {
                    yOffset = UIScreen.main.bounds.height + 100
                    rotation += Double.random(in: 180...720)
                }
            }
    }
}

// Wrapper for PhotoAnalysisView
struct PhotoAnalysisViewWrapper: View {
    @Binding var currentStep: OnboardingStep
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        PhotoAnalysisView()
            .environmentObject(viewModel)
            .onReceive(viewModel.$isComplete) { isComplete in
                if isComplete {
                    currentStep = .complete
                }
            }
    }
}

// Simple OnboardingViewModel for coordination
class OnboardingViewModel: ObservableObject {
    @Published var isComplete = false
    
    func completeOnboarding() {
        Task {
            do {
                // Update the profile to mark onboarding as completed
                let session = try await SupabaseManager.shared.auth.session
                
                struct OnboardingUpdate: Codable {
                    let onboarding_completed: Bool
                    let updated_at: String
                }
                
                let update = OnboardingUpdate(
                    onboarding_completed: true,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(update)
                    .eq("id", value: session.user.id.uuidString)
                    .execute()
                
                print("✅ Onboarding marked as completed")
                
                await MainActor.run {
                    isComplete = true
                }
            } catch {
                print("❌ Error marking onboarding complete: \(error)")
                // Still complete the UI flow even if update fails
                await MainActor.run {
                    isComplete = true
                }
            }
        }
    }
}