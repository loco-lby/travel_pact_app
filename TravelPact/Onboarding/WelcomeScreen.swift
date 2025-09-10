import SwiftUI
import MapKit

struct WelcomeScreen: View {
    @Binding var currentStep: OnboardingStep
    @State private var animateElements = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            // Globe background with blur overlay
            SpinningGlobeBackground(spinSpeed: 20.0)
                .ignoresSafeArea()
            
            // Blurred overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .background(
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                )
            
            // Confetti layer
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        .scaleEffect(animateElements ? 1.0 : 0.8)
                        .opacity(animateElements ? 1.0 : 0.0)
                    
                    VStack(spacing: 12) {
                        Text("TravelPact")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Connect with locals through authentic exchanges")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
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
                        HStack(spacing: 40) {
                            FeatureIcon(
                                icon: "person.2.fill",
                                title: "Meet Locals",
                                color: .blue
                            )
                            
                            FeatureIcon(
                                icon: "gift.fill",
                                title: "Share Skills",
                                color: .blue
                            )
                            
                            FeatureIcon(
                                icon: "sparkles",
                                title: "Create Magic",
                                color: .pink
                            )
                        }
                        .padding(.horizontal, 32)
                    }
                    .offset(y: animateElements ? 0 : 30)
                    .opacity(animateElements ? 1.0 : 0.0)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentStep = .phoneAuth
                        }
                    }) {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                    .padding(.horizontal, 32)
                    .offset(y: animateElements ? 0 : 40)
                    .opacity(animateElements ? 1.0 : 0.0)
                    
                    Text("Your journey starts with a single connection")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 20)
                        .opacity(animateElements ? 1.0 : 0.0)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateElements = true
            }
            
            // Show confetti after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showConfetti = true
            }
        }
    }
}

struct FeatureIcon: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}