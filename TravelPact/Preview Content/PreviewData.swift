import SwiftUI
import CoreLocation

struct PreviewData {
    static let sampleLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    static let sampleUserProfile = UserProfile(
        id: UUID(),
        phone: "+1234567890",
        name: "John Doe",
        photoURL: nil,
        location: LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "San Francisco, CA",
            city: "San Francisco",
            country: "USA"
        ),
        skills: ["Kiteboarding", "Photography", "Cooking"],
        createdAt: Date(),
        updatedAt: Date()
    )
}

#Preview("Welcome Screen") {
    WelcomeScreen(currentStep: .constant(.welcome))
}

#Preview("Phone Auth Screen") {
    PhoneAuthScreen(currentStep: .constant(.phoneAuth))
}

#Preview("Profile Creation") {
    ProfileCreationScreen(currentStep: .constant(.profileCreation))
}

// Removed from onboarding flow - keeping for potential future use
// #Preview("Location Setting") {
//     LocationSettingScreen(currentStep: .constant(.locationSetting))
// }

// #Preview("Skills & Gifts") {
//     SkillsGiftsScreen(currentStep: .constant(.skillsGifts))
// }

#Preview("Onboarding Complete") {
    OnboardingCompleteScreen(showMainApp: .constant(false))
}

#Preview("Liquid Glass Button") {
    ZStack {
        AnimatedGradientBackground()
        
        VStack(spacing: 20) {
            Button("Primary Button") {}
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
            
            Button("Secondary Button") {}
                .buttonStyle(LiquidGlassButtonStyle(isPrimary: false))
        }
        .padding()
    }
}

#Preview("Liquid Glass TextField") {
    ZStack {
        AnimatedGradientBackground()
        
        VStack(spacing: 20) {
            LiquidGlassTextField(
                placeholder: "Enter your name",
                text: .constant("")
            )
            .padding()
        }
    }
}

#Preview("Main Tab View") {
    MainTabView()
}