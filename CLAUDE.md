# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TravelPact is a SwiftUI-based iOS app for social travel that intelligently tracks journeys, preserves connections, and transforms how travelers share stories. The app features an interactive 3D globe interface with location-aware networking and automated travel history generation from photos.

## Build & Development Commands

### Build the project
```bash
xcodebuild -project TravelPact.xcodeproj -scheme TravelPact -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Run the app in simulator
```bash
xcodebuild -project TravelPact.xcodeproj -scheme TravelPact -destination 'platform=iOS Simulator,name=iPhone 15 Pro' run
```

### Clean build folder
```bash
xcodebuild -project TravelPact.xcodeproj -scheme TravelPact clean
```

### Generate Xcode project from project.yml (using XcodeGen)
```bash
xcodegen generate
```

### Swift Package Manager commands
```bash
swift package resolve  # Resolve dependencies
swift build           # Build the package
```

## Architecture & Key Components

### Core Technologies
- **SwiftUI** - iOS 17+ modern declarative UI
- **MapKit** - Interactive 3D globe with satellite imagery
- **Supabase** - Backend (auth, database, storage, realtime)
- **CoreLocation** - Privacy-first location services
- **Photos Framework** - EXIF data analysis for waypoint generation

### Project Structure
- `TravelPact/` - Main app code
  - `TravelPactApp.swift` - App entry point with authentication management
  - `MainTabView.swift` - Main navigation after authentication
  - `Config/AppConfig.swift` - Environment configuration and Supabase setup
  - `Services/` - Core service managers
    - `SupabaseClient.swift` - Supabase singleton manager
    - `LocationPrivacyManager.swift` - Privacy-focused location handling
    - `ConnectionsManager.swift` - Contact/connection management
    - `PhotoAnalysisService.swift` - Photo EXIF analysis
    - `WaypointsManager.swift` - Travel waypoint management
  - `Onboarding/` - Onboarding flow screens
    - `OnboardingCoordinator.swift` - Coordinates onboarding flow
  - `Views/` - Main app views
    - `GlobeView.swift` - 3D interactive globe
  - `Design/LiquidGlass.swift` - Liquid Glass UI components

### Database Schema (Supabase)
Key tables defined in `supabase_setup.sql` and `supabase_migration_locations.sql`:
- `profiles` - User profiles with location, skills, and onboarding status
- `waypoints` - Travel location points with media
- `routes` - Connected travel paths between waypoints
- `pacts` - Travel sharing groups
- `connections` - User relationships and contacts

### Authentication Flow
1. Phone-based SMS OTP authentication via Supabase Auth
2. Profile creation during onboarding
3. `AuthenticationManager` in TravelPactApp.swift manages auth state
4. Profile completion tracked via `onboarding_completed` field

### Environment Configuration
- `.env.local` file contains Supabase credentials (gitignored)
- `AppConfig.swift` loads environment variables
- Required keys: `SUPABASE_URL`, `SUPABASE_ANON_PUBLIC`

### Design System
- Liquid Glass interface - translucent, dynamic controls
- Purple for app users, orange for contacts
- Spatial interactions with gesture-driven navigation
- AnimatedGradientBackground for immersive experiences

## Important Notes

- Minimum iOS deployment target: 17.0
- Uses Row-Level Security (RLS) in Supabase for privacy
- Location privacy system with three levels: actual (device-only), known (public, obfuscated), and smart travel detection
- Contact bridge system tracks both app users and regular contacts
- Photo analysis automatically generates waypoints from EXIF data
- Remeber you have access to supabase mcp, the project id is in the env.local
- Remember you haves access to supabase via mcp, the project id is in env.local