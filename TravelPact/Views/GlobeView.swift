import SwiftUI
import MapKit
import CoreLocation

struct GlobeView: View {
    @StateObject private var locationManager = LocationPrivacyManager.shared
    @StateObject private var connectionsManager = ConnectionsManager()
    @StateObject private var waypointsManager = WaypointsManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showLocationUpdate = false
    @State private var showLocationPicker = false
    @State private var showAddConnection = false
    @State private var selectedConnection: Connection?
    @State private var selectedWaypoint: Waypoint?
    @State private var selectedRoute: UUID?
    @State private var showWaypointDetails = false
    @State private var waypointToDelete: Waypoint?
    @State private var showDeleteAlert = false
    @State private var routePathAnimation: Double = 0
    @State private var globeRotation: Double = 0
    @State private var isInitialLoad = true
    
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        // User's known location
        if let knownLocation = locationManager.knownLocation {
            Annotation("", coordinate: knownLocation) {
                PulsingLocationMarker(isUser: true)
                    .onTapGesture {
                        showLocationUpdate = true
                    }
            }
        }
        
        // Route paths between waypoints
        if waypointsManager.waypoints.count > 1 {
            createRoutePaths(
                waypoints: waypointsManager.waypoints,
                animation: routePathAnimation
            )
        }
        
        // Waypoint markers
        ForEach(waypointsManager.waypoints) { waypoint in
            if let coordinate = waypoint.coordinate {
                Annotation("", coordinate: coordinate) {
                    WaypointMarker(
                        waypoint: waypoint,
                        isSelected: selectedWaypoint?.id == waypoint.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedWaypoint = selectedWaypoint?.id == waypoint.id ? nil : waypoint
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        waypointToDelete = waypoint
                        showDeleteAlert = true
                    }
                }
            }
        }
        
        // Connection markers
        ForEach(connectionsManager.visibleConnections) { connection in
            if let coordinate = connection.displayCoordinate {
                Annotation("", coordinate: coordinate) {
                    ConnectionDot(
                        connection: connection,
                        isSelected: selectedConnection?.id == connection.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedConnection = selectedConnection?.id == connection.id ? nil : connection
                        }
                    }
                }
            }
        }
    }
    
    private var gradientOverlay: some View {
        VStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.4),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .ignoresSafeArea()
            
            Spacer()
            
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
    
    private var floatingUILayer: some View {
        VStack {
            // Top Bar
            HStack {
                LocationAccuracyPill(accuracy: locationManager.locationAccuracy)
                    .padding(.leading)
                
                Spacer()
                
                FloatingGlassButton(
                    icon: "person.badge.plus",
                    size: .medium
                ) {
                    showAddConnection = true
                }
                .padding(.trailing)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Info cards area
            VStack(spacing: 16) {
                // Travel Suggestion
                if locationManager.showTravelSuggestion {
                    TravelUpdateCard(
                        distance: locationManager.travelDistance,
                        onUpdate: {
                            showLocationUpdate = true
                            locationManager.dismissTravelSuggestion()
                        },
                        onDismiss: {
                            locationManager.dismissTravelSuggestion()
                        }
                    )
                    .padding(.horizontal, 24)
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .push(from: .top).combined(with: .opacity)
                    ))
                }
                
                // Selected Waypoint Card
                if let waypoint = selectedWaypoint {
                    WaypointInfoCard(
                        waypoint: waypoint,
                        onClose: {
                            withAnimation {
                                selectedWaypoint = nil
                            }
                        },
                        onEdit: {
                            showWaypointDetails = true
                        },
                        onDelete: {
                            waypointToDelete = waypoint
                            showDeleteAlert = true
                        }
                    )
                    .padding(.horizontal, 24)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
                
                // Selected Connection Card
                if let connection = selectedConnection {
                    ConnectionInfoCard(
                        connection: connection,
                        onClose: {
                            withAnimation {
                                selectedConnection = nil
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            
            // Bottom Control Cluster
            HStack(spacing: 16) {
                FloatingGlassButton(
                    icon: "location.north.fill",
                    size: .large
                ) {
                    centerOnUserLocation()
                }
                
                Spacer()
                
                FloatingGlassButton(
                    icon: "globe.americas.fill",
                    size: .large
                ) {
                    showFullGlobe()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
    }
    
    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                mapAnnotations
            }
            .mapStyle(.hybrid(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {
                // Empty - removes default controls
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupInitialGlobeView()
            waypointsManager.loadWaypoints()
            
            // Animate route paths after waypoints load
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    routePathAnimation = 1.0
                }
            }
        }
        .onChange(of: waypointsManager.waypoints) { _ in
            // Re-animate when waypoints change
            routePathAnimation = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    routePathAnimation = 1.0
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            mapView
            gradientOverlay
            floatingUILayer
        }
        .preferredColorScheme(.dark) // Force dark mode for better globe visibility
        .sheet(isPresented: $showLocationUpdate) {
            LocationUpdateView()
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationSearchView { coordinate, name in
                locationManager.updateKnownLocation(coordinate: coordinate, name: name)
                centerOnUserLocation()
            }
        }
        .sheet(isPresented: $showAddConnection) {
            AddConnectionView()
                .environmentObject(connectionsManager)
        }
        .sheet(isPresented: $showWaypointDetails) {
            if let waypoint = selectedWaypoint {
                WaypointEditView(waypoint: waypoint) { updatedWaypoint in
                    waypointsManager.updateWaypoint(updatedWaypoint)
                }
            }
        }
        .alert("Delete Waypoint", isPresented: $showDeleteAlert) {
            Button("Delete Waypoint Only", role: .destructive) {
                if let waypoint = waypointToDelete {
                    deleteWaypoint(waypoint, splitRoute: false)
                }
            }
            Button("Split Route Here", role: .destructive) {
                if let waypoint = waypointToDelete {
                    deleteWaypoint(waypoint, splitRoute: true)
                }
            }
            Button("Cancel", role: .cancel) {
                waypointToDelete = nil
            }
        } message: {
            if let waypoint = waypointToDelete {
                Text("Delete \(waypoint.name)? You can either delete just this waypoint or split the route at this point.")
            }
        }
    }
    
    private func setupInitialGlobeView() {
        guard isInitialLoad else { return }
        isInitialLoad = false
        
        // Load connections
        connectionsManager.loadConnections()
        
        // Start with full globe view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showFullGlobe()
            
            // Then focus on user location after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if locationManager.knownLocation != nil {
                    centerOnUserLocation()
                }
            }
        }
    }
    
    private func centerOnUserLocation() {
        guard let location = locationManager.knownLocation else {
            showLocationPicker = true
            return
        }
        
        withAnimation(.interpolatingSpring(stiffness: 80, damping: 15)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 1_500_000, // 1,500km altitude
                    heading: 0,
                    pitch: 65 // Angled view for 3D effect
                )
            )
        }
    }
    
    private func showFullGlobe() {
        withAnimation(.interpolatingSpring(stiffness: 60, damping: 12)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    distance: 20_000_000, // 20,000km altitude - see full globe
                    heading: globeRotation,
                    pitch: 0
                )
            )
        }
        
        // Subtle rotation animation
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            globeRotation = 360
        }
    }
    
    private func deleteWaypoint(_ waypoint: Waypoint, splitRoute: Bool) {
        Task {
            do {
                if splitRoute {
                    // Split route at this waypoint
                    try await waypointsManager.splitRouteAtWaypoint(waypoint)
                } else {
                    // Just delete the waypoint
                    try await waypointsManager.deleteWaypoint(waypoint)
                }
                
                await MainActor.run {
                    selectedWaypoint = nil
                    waypointToDelete = nil
                    // Note: loadWaypoints is called automatically by the manager after deletion
                }
            } catch {
                print("Error deleting waypoint: \(error)")
            }
        }
    }
}

// MARK: - Pulsing Location Marker
struct PulsingLocationMarker: View {
    let isUser: Bool
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer pulse rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                isUser ? Color.blue : Color.purple,
                                isUser ? Color.cyan : Color.pink
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 30 + CGFloat(index * 15), height: 30 + CGFloat(index * 15))
                    .opacity(isPulsing ? 0 : 0.6)
                    .scaleEffect(isPulsing ? 1.5 : 1)
                    .animation(
                        .easeOut(duration: 2)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.5),
                        value: isPulsing
                    )
            }
            
            // Center dot
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            isUser ? Color.blue : Color.purple,
                            isUser ? Color.cyan : Color.pink
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: isUser ? .blue : .purple, radius: 10)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Connection Dot
struct ConnectionDot: View {
    let connection: Connection
    let isSelected: Bool
    
    var dotColor: LinearGradient {
        if connection.hasAccount {
            // App user - solid gradient
            return LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Non-app user - orange gradient
            return LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(dotColor)
                    .frame(width: 30, height: 30)
                    .blur(radius: 15)
            }
            
            Group {
                if connection.hasAccount {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 16, height: 16)
                } else {
                    Circle()
                        .stroke(dotColor, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.3 : 1)
                .shadow(color: .black.opacity(0.3), radius: 3)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Floating Glass Button
struct FloatingGlassButton: View {
    let icon: String
    let size: ButtonSize
    let action: () -> Void
    
    enum ButtonSize {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 50
            case .large: return 60
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 22
            case .large: return 26
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Glass background
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: size.dimension, height: size.dimension)
            .overlay(
                Circle()
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
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Location Accuracy Pill
struct LocationAccuracyPill: View {
    let accuracy: LocationAccuracy
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            
            Text(accuracy.displayName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            Capsule()
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
        .shadow(color: .black.opacity(0.2), radius: 8)
    }
}

// MARK: - Travel Update Card
struct TravelUpdateCard: View {
    let distance: Double
    let onUpdate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("You've traveled \(Int(distance))km")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Update your known location?")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Not Now")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                
                Button(action: onUpdate) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                        Text("Update")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
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
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Connection Info Card
struct ConnectionInfoCard: View {
    let connection: Connection
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Status indicator
                Circle()
                    .fill(connection.hasAccount ? 
                          LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(connection.hasAccount ? "On TravelPact" : "Invite to TravelPact")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(connection.hasAccount ? .green : .orange)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            
            if let locationName = connection.displayLocationName {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(locationName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            if !connection.hasAccount {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("Send Invite")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
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
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Waypoint Marker
struct WaypointMarker: View {
    let waypoint: Waypoint
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Outer ring with animation
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 50 : 30, height: isSelected ? 50 : 30)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
            
            // Inner dot
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 20 : 12, height: isSelected ? 20 : 12)
                .shadow(color: .blue.opacity(0.6), radius: 6, x: 0, y: 2)
            
            // Pin icon
            Image(systemName: "mappin")
                .font(.system(size: isSelected ? 12 : 8, weight: .bold))
                .foregroundColor(.white)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}


// MARK: - Waypoint Info Card
struct WaypointInfoCard: View {
    let waypoint: Waypoint
    let onClose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        
        if let arrival = waypoint.arrivalTime, let departure = waypoint.departureTime {
            if Calendar.current.isDate(arrival, inSameDayAs: departure) {
                return formatter.string(from: arrival)
            } else {
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = Calendar.current.component(.year, from: arrival) == Calendar.current.component(.year, from: departure) ? "MMM d" : "MMM d, yyyy"
                return "\(formatter.string(from: arrival)) - \(endFormatter.string(from: departure))"
            }
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Location icon
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(waypoint.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(dateRangeText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            
            // Location details
            if let city = waypoint.city {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text([city, waypoint.region, waypoint.country]
                        .compactMap { $0 }
                        .joined(separator: ", "))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text("Edit")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                    )
                }
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.3))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
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
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}
