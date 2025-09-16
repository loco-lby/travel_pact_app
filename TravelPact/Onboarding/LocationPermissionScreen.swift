import SwiftUI
import CoreLocation

struct LocationPermissionScreen: View {
    @Binding var currentStep: OnboardingStep
    @StateObject private var locationManager = LocationPrivacyManager.shared
    @State private var animateElements = false
    @State private var permissionStatus: CLAuthorizationStatus = .notDetermined
    @State private var showingDeniedAlert = false
    
    var body: some View {
        ZStack {
            // Background
            SpinningGlobeBackground(spinSpeed: 20.0)
                .ignoresSafeArea()
            
            // Glass overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .background(
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon and title
                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.cyan.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.5), radius: 20)
                    }
                    .scaleEffect(animateElements ? 1.0 : 0.5)
                    .opacity(animateElements ? 1.0 : 0.0)
                    
                    VStack(spacing: 16) {
                        Text("Enable Location Services")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("TravelPact helps you create bookmarks and track locations of friends and family")
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .offset(y: animateElements ? 0 : 20)
                    .opacity(animateElements ? 1.0 : 0.0)
                }
                
                // Features
                VStack(spacing: 24) {
                    LocationFeature(
                        icon: "bookmark.circle.fill",
                        title: "Create Bookmarks",
                        description: "Save memorable places and locations"
                    )
                    
                    LocationFeature(
                        icon: "person.2.circle.fill",
                        title: "Track Contacts",
                        description: "See where your friends and family are located"
                    )
                    
                    LocationFeature(
                        icon: "lock.shield",
                        title: "Privacy Control",
                        description: "You control what location detail you share"
                    )
                }
                .padding(.horizontal, 32)
                .offset(y: animateElements ? 0 : 30)
                .opacity(animateElements ? 1.0 : 0.0)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    // Show info text when user has When In Use permission
                    if permissionStatus == .authorizedWhenInUse {
                        Text("✓ Location access granted")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.bottom, 8)
                        
                        Text("Background tracking is optional. You can enable it later in Settings for automatic location updates.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                    
                    Button(action: requestLocationPermission) {
                        HStack {
                            if permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways {
                                Image(systemName: "checkmark.circle.fill")
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text(buttonTitle)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                    
                    if permissionStatus == .notDetermined {
                        Button(action: skipLocationPermission) {
                            Text("Maybe Later")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isPrimary: false))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
                .offset(y: animateElements ? 0 : 40)
                .opacity(animateElements ? 1.0 : 0.0)
            }
        }
        .onAppear {
            checkPermissionStatus()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateElements = true
            }
        }
        .onChange(of: locationManager.currentAuthorizationStatus) { oldStatus, newStatus in
            permissionStatus = newStatus
            // Auto-proceed if permission granted (either always or when in use)
            if newStatus == .authorizedAlways || newStatus == .authorizedWhenInUse {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentStep = .complete
                }
            }
        }
        .alert("Location Access Denied", isPresented: $showingDeniedAlert) {
            Button("Open Settings", action: openSettings)
            Button("Continue Without Location", action: skipLocationPermission)
        } message: {
            Text("To use location features, please enable location access in Settings > TravelPact > Location")
        }
    }
    
    private var buttonTitle: String {
        switch permissionStatus {
        case .notDetermined:
            return "Enable Location"
        case .denied, .restricted:
            return "Open Settings"
        case .authorizedWhenInUse:
            return "Continue" // Changed from "Enable Background Tracking" since it's optional
        case .authorizedAlways:
            return "Continue"
        @unknown default:
            return "Enable Location"
        }
    }
    
    private func checkPermissionStatus() {
        let status = locationManager.currentAuthorizationStatus
        permissionStatus = status
        
        print("📍 LocationPermissionScreen: Current status = \(status.rawValue)")
        
        // Auto-proceed if already authorized (either Always or When In Use)
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            print("📍 LocationPermissionScreen: Already have permission \(status.rawValue), auto-proceeding")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentStep = .complete
            }
        }
    }
    
    private func requestLocationPermission() {
        print("📍 LocationPermissionScreen: Button clicked, current status = \(permissionStatus.rawValue)")
        
        // Re-check current status in case it changed
        checkPermissionStatus()
        
        switch permissionStatus {
        case .notDetermined:
            print("📍 LocationPermissionScreen: Requesting When In Use permission")
            requestWhenInUsePermission()
        case .authorizedWhenInUse:
            print("📍 LocationPermissionScreen: User has When In Use permission, proceeding")
            // User has When In Use permission, that's sufficient - proceed
            currentStep = .complete
        case .denied, .restricted:
            print("📍 LocationPermissionScreen: Permission denied, showing alert")
            showingDeniedAlert = true
        case .authorizedAlways:
            print("📍 LocationPermissionScreen: Already authorized, proceeding")
            // Already have full permission, proceed immediately
            currentStep = .complete
        @unknown default:
            break
        }
    }
    
    private func requestWhenInUsePermission() {
        locationManager.requestLocationPermission { granted in
            DispatchQueue.main.async {
                checkPermissionStatus()
                if granted {
                    // User granted When In Use, that's sufficient - proceed
                    currentStep = .complete
                }
            }
        }
    }
    
    private func requestAlwaysPermission() {
        // Note: This function is kept for potential future use but is not called in the current flow
        // Users with "When In Use" permission can proceed immediately
        locationManager.requestAlwaysAuthorization { granted in
            DispatchQueue.main.async {
                checkPermissionStatus()
                // Proceed regardless of whether Always was granted
                currentStep = .complete
            }
        }
    }
    
    private func skipLocationPermission() {
        currentStep = .complete
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct LocationFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}