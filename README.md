# TravelPact

A SwiftUI iOS app for connecting travelers through authentic local exchanges, featuring iOS 26 Liquid Glass design and Supabase backend integration.

## Features

- **Complete Onboarding Flow**: 5-screen onboarding with phone authentication, profile creation, location setting, and skills input
- **iOS 26 Liquid Glass Design**: Modern glass morphism effects with animated gradients and translucent UI elements
- **Supabase Integration**: Phone authentication, user profiles, photo storage, and location data
- **3D Globe Visualization**: Interactive SceneKit globe for location selection
- **Privacy-Focused**: User-controlled location sharing with clear privacy messaging

## Setup Instructions

1. **Open in Xcode**:
   ```bash
   open TravelPact.xcodeproj
   ```

2. **Install Dependencies**:
   - Xcode will automatically fetch the Supabase Swift package when you open the project
   - If not, go to File > Packages > Resolve Package Versions

3. **Environment Variables**:
   - The project already includes `.env.local` with Supabase credentials
   - These are automatically loaded in the Xcode scheme

4. **Required Permissions**:
   - Camera access for profile photos
   - Photo library access for profile photos
   - Location services for setting user location

5. **Build and Run**:
   - Select your target device/simulator (iOS 17.0+)
   - Press Cmd+R to build and run

## Project Structure

```
TravelPact/
├── TravelPactApp.swift          # Main app entry point
├── MainTabView.swift            # Post-onboarding tab navigation
├── Design/
│   └── LiquidGlass.swift        # Liquid Glass design system
├── Services/
│   └── SupabaseClient.swift     # Supabase configuration and models
├── Onboarding/
│   ├── WelcomeScreen.swift      # Welcome screen with app intro
│   ├── PhoneAuthScreen.swift    # Phone authentication with OTP
│   ├── ProfileCreationScreen.swift # Name and photo setup
│   ├── LocationSettingScreen.swift # 3D globe location selector
│   ├── SkillsGiftsScreen.swift  # Skills and gifts input
│   └── OnboardingCoordinator.swift # Manages onboarding flow
└── Preview Content/
    └── PreviewData.swift        # SwiftUI preview helpers
```

## Supabase Configuration

The app uses Supabase for:
- Phone authentication (OTP)
- User profile storage (profiles table)
- Photo storage (profiles bucket)
- Location data with privacy controls

## Design System

The iOS 26 Liquid Glass design includes:
- Glass morphism effects with blur and transparency
- Animated gradient backgrounds
- Custom button styles with glow effects
- Translucent text fields
- Smooth spring animations between screens

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Preview & Debug

Use SwiftUI previews to test individual screens:
- Open any screen file
- Click the Canvas button in Xcode
- Use the preview controls to test different states

## Notes

- The app stores user data securely in Supabase
- Location data is private by default
- All UI elements follow iOS 26 design guidelines
- Smooth transitions and animations throughout