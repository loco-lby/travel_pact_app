import SwiftUI
import Contacts

struct ContactSyncOnboardingScreen: View {
    @Binding var currentStep: OnboardingStep
    @StateObject private var contactService = ContactSyncService.shared
    @StateObject private var locationManager = ContactLocationManager.shared
    @State private var animateElements = false
    @State private var isLoading = false
    @State private var showPermissionDenied = false
    @State private var contactsCount = 0
    @State private var showContactPreview = false
    @State private var previewContacts: [TravelPactContact] = []
    
    var body: some View {
        ZStack {
            // Animated gradient background
            OnboardingAnimatedGradientBackground()
                .ignoresSafeArea()
            
            // Blurred overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .background(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 0) {
                // Top section with illustration and title
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Illustration
                    ZStack {
                        // Background glow
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.4),
                                        Color.purple.opacity(0.3),
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 40)
                            .scaleEffect(animateElements ? 1.2 : 0.8)
                        
                        // Contact illustrations
                        ZStack {
                            ForEach(0..<6, id: \.self) { index in
                                let angle = Double(index) * 60.0
                                let radius: CGFloat = 60
                                
                                ContactBubbleIllustration(
                                    initials: ["AB", "CD", "EF", "GH", "IJ", "KL"][index],
                                    color: [.orange, .blue, .green, .purple, .pink, .cyan][index]
                                )
                                .offset(
                                    x: cos(angle * .pi / 180) * radius,
                                    y: sin(angle * .pi / 180) * radius
                                )
                                .rotationEffect(.degrees(animateElements ? angle + 360 : angle))
                                .scaleEffect(animateElements ? 1.0 : 0.6)
                                .opacity(animateElements ? 1.0 : 0.3)
                                .animation(
                                    .spring(response: 1.0, dampingFraction: 0.6)
                                        .delay(Double(index) * 0.1),
                                    value: animateElements
                                )
                            }
                            
                            // Center globe
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(animateElements ? 1.0 : 0.5)
                                .opacity(animateElements ? 1.0 : 0.0)
                        }
                    }
                    .frame(height: 200)
                    
                    // Title and description
                    VStack(spacing: 20) {
                        Text("Connect with Friends")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(animateElements ? 1.0 : 0.0)
                            .offset(y: animateElements ? 0 : 20)
                        
                        Text("Sync your contacts to see who else uses TravelPact and assign locations to friends around the world")
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .opacity(animateElements ? 1.0 : 0.0)
                            .offset(y: animateElements ? 0 : 30)
                    }
                    
                    Spacer()
                }
                
                // Bottom section with actions
                VStack(spacing: 24) {
                    if showContactPreview && !previewContacts.isEmpty {
                        // Contact preview section
                        VStack(spacing: 16) {
                            Text("Found \(contactsCount) contacts")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(previewContacts.prefix(8)) { contact in
                                        ContactInitialsBubble(
                                            initials: contact.bubbleInitials,
                                            hasAccount: contact.hasAccount,
                                            hasLocation: false
                                        )
                                        .frame(width: 48, height: 48)
                                    }
                                    
                                    if contactsCount > 8 {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 48, height: 48)
                                            
                                            Text("+\(contactsCount - 8)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                        .padding(.horizontal, 20)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        if contactService.hasPermission && showContactPreview {
                            Button("Continue with \(contactsCount) Contacts") {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentStep = .locationPermission
                                }
                            }
                            .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                            .disabled(isLoading)
                        } else {
                            Button(isLoading ? "Syncing Contacts..." : "Sync My Contacts") {
                                syncContacts()
                            }
                            .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                            .disabled(isLoading)
                        }
                        
                        Button("Skip for Now") {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentStep = .locationPermission
                            }
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isPrimary: false))
                    }
                    .padding(.horizontal, 32)
                    .opacity(animateElements ? 1.0 : 0.0)
                    .offset(y: animateElements ? 0 : 40)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateElements = true
            }
            
            // Check if contacts are already synced
            if contactService.hasPermission && !contactService.contacts.isEmpty {
                showContactPreview = true
                contactsCount = contactService.contacts.count
                previewContacts = Array(contactService.contacts.prefix(8))
            }
        }
        .alert("Permission Denied", isPresented: $showPermissionDenied) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Continue Without Contacts") {
                currentStep = .locationPermission
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Contact access was denied. You can enable it in Settings or continue without contact sync.")
        }
    }
    
    private func syncContacts() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            let hasPermission = await contactService.requestContactsPermission()
            
            if hasPermission {
                await contactService.syncContacts()
                
                await MainActor.run {
                    isLoading = false
                    contactsCount = contactService.contacts.count
                    previewContacts = Array(contactService.contacts.prefix(8))
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showContactPreview = true
                    }
                }
            } else {
                await MainActor.run {
                    isLoading = false
                    showPermissionDenied = true
                }
            }
        }
    }
}

// MARK: - Contact Bubble Illustration
struct ContactBubbleIllustration: View {
    let initials: String
    let color: Color
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .overlay(
                Text(initials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Animated Gradient Background (reused)
struct OnboardingAnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.purple.opacity(0.4),
                Color.orange.opacity(0.3),
                Color.blue.opacity(0.3),
                Color.black
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}