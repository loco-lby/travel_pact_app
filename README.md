# TravelPact

> Where fleeting connections become lasting relationships

A social travel platform that intelligently tracks your journeys, preserves connections, and transforms how travelers share their stories.

## 🎯 Recent Updates

### Simplified Location System (Latest)
- **Removed Granularity Selector** - Simplified location tracking to use accurate current location
- **Direct Waypoint Creation** - Waypoints now created at exact current location
- **Cleaner UI** - Removed granularity controls for more intuitive user experience
- **Photo Analysis Focus** - Granularity now only applies to photo-based waypoint creation

### UI Improvements
- **Streamlined Interface** - Removed bottom tab bar for cleaner single-screen experience
- **Profile Access** - Added profile bubble in top right corner for quick settings access
- **Profile Menu** - View user info, settings, privacy options, help, and logout
- **Contact Cards** - Interactive cards for non-TravelPact contacts with assigned locations
- **Native Integration** - Direct call and message buttons that open iOS native apps

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- Swift 5.9+
- Supabase account for backend services

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/travel_pact_app.git
cd travel_pact_app
```

2. Set up environment variables:
```bash
cp .env.example .env.local
# Edit .env.local with your Supabase credentials:
# SUPABASE_URL=your_supabase_url
# SUPABASE_ANON_PUBLIC=your_anon_key
```

3. Generate Xcode project (if using XcodeGen):
```bash
xcodegen generate
```

4. Open in Xcode:
```bash
open TravelPact.xcodeproj
```

5. Build and run (⌘+R) or via command line:
```bash
xcodebuild -project TravelPact.xcodeproj -scheme TravelPact -destination 'platform=iOS Simulator,name=iPhone 15 Pro' run
```
## 📱 The Problem We're Solving

As frequent travelers, we've all experienced this: You meet amazing people on your adventures, exchange contacts with promises to "meet up if you're ever in my city." Months later, when you're in Napa Valley, you completely forget who you know there. Their contact sits unnamed in your phone, their Instagram handle is forgotten, and meaningful connections fade into digital noise.

Meanwhile, your travels - the experiences that define you - are scattered across hundreds of unorganized photos that are too overwhelming to curate and share.

## ✨ How TravelPact Changes Everything
TravelPact is the travel companion every explorer needs, built around three core innovations:

### 🌍 Intelligent Connection Mapping
- **Phone-based contact sync** - Track connections by phone numbers for automatic profile linking
- **Location-aware networking** - Remember who you know in every city
- **Connection visualization** - See your global network mapped on an interactive 3D globe

### 📸 Automated Travel History
- **Smart photo analysis** - Automatically build your travel timeline from existing photos
- **EXIF metadata processing** - Extract location and timestamp data to create waypoints
- **Effortless organization** - No manual data entry required

### 🤝 Social Travel Pacts
- **Live travel sharing** - Create "pacts" to share real-time location and media with travel companions
- **Collaborative media** - Solve the eternal problem of collecting photos from group trips
- **Timeline curation** - Select and share your favorite travel stories with your network

## 🎯 Key Features
### Privacy-First Location System
- Actual location (device-only, never stored)
- Known location (public, obfuscated to city/region/country level)
- Smart travel detection (100km threshold triggers location updates)
- Granular privacy controls for every shared element

### Interactive 3D Globe Interface
- MapKit satellite imagery with smooth camera animations
- Pulsing location markers showing your journey
- Color-coded connections (purple for app users, orange for contacts)
- Liquid Glass controls floating above the immersive experience

### Smart Route & Media Management
- Automatic waypoint generation from photo analysis
- Route visualization showing connected travel experiences
- Media sorting with swipe-to-categorize (public/private/trash)
- Slideshow creation for sharing curated travel stories

### Mixed Network Integration
- Contact bridge - Track both app users and regular contacts
- Automatic upgrades when contacts join TravelPact
- Visual distinction between user types
- Seamless connection management

## 🎨 Design Philosophy

Built using Apple's latest iOS design principles:
- **Liquid Glass interface** - Translucent, dynamic controls that adapt to content
- **Spatial interactions** - Gesture-driven navigation that feels natural
- **Progressive disclosure** - Complexity revealed only when needed
- **Immersive experience** - The globe as your primary interface, not just another map

## 🛠 Technical Architecture

- **SwiftUI** - Modern declarative UI with spatial layout capabilities
- **MapKit** - Interactive 3D globe with satellite imagery
- **CoreLocation** - Privacy-focused location services
- **Photos Framework** - EXIF data analysis for automatic waypoint generation
- **Supabase** - Backend database, authentication, and file storage
- **Row-Level Security** - Granular privacy controls at the database level

## 📊 Current Status

### ✅ Completed Features
- Phone-based authentication with SMS OTP
- Interactive 3D globe interface with location markers
- Privacy-first location system with granular controls
- Contact integration and connection visualization
- Database schema for waypoints, routes, media, and pacts
- Liquid Glass UI components throughout

### 🚧 In Development
- Photo analysis and automatic waypoint generation
- Media sorting and slideshow functionality
- Real-time pact sharing
- Push notifications for connection updates
- Advanced route visualization

## 📈 Growth Strategy

TravelPact is designed to grow through genuine human connection:
- **Emotional marketing** - Making a pact with someone creates profound emotional connection
- **Network effects** - Each new user increases value for existing users
- **Travel community targeting** - Starting with hostels, travel influencers, and adventure communities
- **Word-of-mouth amplification** - Authentic travel stories drive organic growth

## 💼 Business Model

Free-to-use to make travel more accessible and inspiring. Future monetization through:
- Contextual travel advertising
- Premium features for power users
- Partnership opportunities with travel services

## 🌟 Vision

In a world where travel is becoming more accessible than ever, TravelPact has the potential to redefine how we form connections and share our stories. This isn't just another social app - it's the missing link between the people we meet and the places we go.

Transform fleeting connections into lasting relationships. Start your TravelPact journey today.

---

**TravelPact** - *Because every journey is better when shared.*

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines (coming soon) for details.

## 📄 License

This project is proprietary software. All rights reserved.

## 📧 Contact

For questions or support, please contact the development team.