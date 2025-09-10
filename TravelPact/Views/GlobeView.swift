import CoreLocation
import MapKit
import SwiftUI
import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct GlobeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.openURL) private var openURL
    @StateObject private var locationManager = LocationPrivacyManager.shared
    @StateObject private var connectionsManager = ConnectionsManager()
    @StateObject private var waypointsManager = WaypointsManager()
    @StateObject private var contactLocationManager = ContactLocationManager.shared
    @StateObject private var contactService = ContactSyncService.shared
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showLocationUpdate = false
    @State private var showLocationPicker = false
    @State private var showAddConnection = false
    @State private var selectedConnection: Connection?
    @State private var selectedWaypoint: Waypoint?
    @State private var selectedRoute: UUID?
    @State private var showWaypointDetails = false
    @State private var showWaypointMedia = false
    @State private var waypointToDelete: Waypoint?
    @State private var showDeleteAlert = false
    @State private var routePathAnimation: Double = 0
    @State private var globeRotation: Double = 0
    @State private var isInitialLoad = true
    @State private var showContactGlobe = false
    @State private var contactForGlobe: TravelPactContact?
    @State private var contactLocationToNavigate: CoordinateWrapper?
    @State private var showLocationPermissionAlert = false
    @State private var showLocationDeniedAlert = false
    @State private var showProfileMenu = false
    @State private var selectedContact: TravelPactContact?

    var body: some View {
        ZStack {
            mapView
            floatingUILayer
        }
        .preferredColorScheme(.dark)  // Force dark mode for better globe visibility
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
        .sheet(isPresented: $showProfileMenu) {
            ProfileMenuView()
                // .environmentObject(authManager)
                .presentationBackground(.clear)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showWaypointDetails) {
            if let waypoint = selectedWaypoint {
                WaypointEditView(waypoint: waypoint) { updatedWaypoint in
                    waypointsManager.updateWaypoint(updatedWaypoint)
                }
            }
        }
        .sheet(isPresented: $showWaypointMedia) {
            if let waypoint = selectedWaypoint {
                WaypointMediaView(waypoint: waypoint)
            }
        }
        .fullScreenCover(isPresented: $showContactGlobe) {
            if let contact = contactForGlobe {
                ContactGlobeView(contact: contact)
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
                Text(
                    "Delete '\(waypoint.name)'? This will remove it from your route. Choose 'Split Route' to create two separate routes at this point."
                )
            }
        }
        .alert("Location Permission Needed", isPresented: $showLocationPermissionAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: "App-Prefs:root=Privacy&path=LOCATION") {
                    openURL(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Please enable location services in Settings to add waypoints at your current location."
            )
        }
        .alert("Location Services Disabled", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: "App-Prefs:root=Privacy&path=LOCATION") {
                    openURL(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Location services are disabled. Please enable them in Settings to use this feature."
            )
        }
    }

    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        // User's location (known or actual)
        if let knownLocation = locationManager.knownLocation {
            Annotation("", coordinate: knownLocation) {
                PulsingLocationMarker(isUser: true)
                    .onTapGesture {
                        showLocationUpdate = true
                    }
            }
        } else if let actualLocation = locationManager.actualLocation {
            Annotation("", coordinate: actualLocation.coordinate) {
                PulsingLocationMarker(isUser: true)
                    .onTapGesture {
                        showLocationUpdate = true
                    }
            }
        }

        // Route paths between waypoints
        // Group waypoints by route ID and draw separate polylines for each route
        let groupedWaypoints = Dictionary(grouping: waypointsManager.waypoints, by: { $0.routeId })

        ForEach(Array(groupedWaypoints.keys), id: \.self) { routeId in
            let routeWaypoints = groupedWaypoints[routeId]!
                .sorted(by: { $0.sequenceOrder < $1.sequenceOrder })

            if routeWaypoints.count > 1 {
                let coordinates = routeWaypoints.compactMap { $0.coordinate }

                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(
                            routeGradient(for: routeId).opacity(routePathAnimation),
                            style: StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
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
                            selectedConnection =
                                selectedConnection?.id == connection.id ? nil : connection
                        }
                    }
                }
            }
        }

        // Contact location markers (for non-user contacts with assigned locations)
        ForEach(contactService.contacts.filter { !$0.hasAccount && $0.contactIdentifier != nil }) {
            contact in
            if let contactId = contact.contactIdentifier,
                let locationData = contactLocationManager.getLocation(for: contactId)
            {
                Annotation("", coordinate: locationData.coordinate) {
                    ContactLocationMarker(
                        contact: contact,
                        locationData: locationData
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedContact = selectedContact?.id == contact.id ? nil : contact
                        }
                    }
                }
            }
        }
    }

    // Gradient overlay removed to eliminate the dark gap at bottom
    // private var gradientOverlay: some View {
    //     VStack {
    //         LinearGradient(
    //             colors: [
    //                 Color.black.opacity(0.4),
    //                 Color.clear,
    //             ],
    //             startPoint: .top,
    //             endPoint: .bottom
    //         )
    //         .frame(height: 200)
    //         .ignoresSafeArea()

    //         Spacer()

    //         LinearGradient(
    //             colors: [
    //                 Color.clear,
    //                 Color.black.opacity(0.4),
    //             ],
    //             startPoint: .top,
    //             endPoint: .bottom
    //         )
    //         .frame(height: 200)
    //         .ignoresSafeArea()
    //     }
    //     .allowsHitTesting(false)
    // }

    private var floatingUILayer: some View {
        return ZStack {
            VStack {
                // Top Bar
                HStack {
                    // Left side: Add waypoint button and media analysis bubble
                    HStack(spacing: 12) {
                        FloatingGlassButton(
                            icon: "plus",
                            size: .small
                        ) {
                            addWaypointAtCurrentLocation()
                        }
                        
                        // Media analysis bubble
                        MediaAnalysisBubble(onWaypointsAdded: {
                            waypointsManager.loadWaypoints()
                        })
                    }
                    .padding(.leading)

                    Spacer()

                    // Right side: Current location button + Profile bubble
                    HStack(spacing: 12) {
                        FloatingGlassButton(
                            icon: "location.north.fill",
                            size: .small
                        ) {
                            centerOnUserLocation()
                        }

                        // Profile bubble
                        Button(action: {
                            showProfileMenu = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.purple.opacity(0.8),
                                                Color.purple.opacity(0.4),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )

                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 42, height: 42)
                            .shadow(color: .black.opacity(0.2), radius: 10)
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.top, 60)

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
                        .transition(
                            .asymmetric(
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
                            },
                            onMedia: {
                                showWaypointMedia = true
                            }
                        )
                        .padding(.horizontal, 24)
                        .transition(
                            .asymmetric(
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
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    }

                    // Selected Contact Card (non-user contacts)
                    if let contact = selectedContact,
                        let contactId = contact.contactIdentifier,
                        let locationData = contactLocationManager.getLocation(for: contactId)
                    {
                        ContactLocationCard(
                            contact: contact,
                            locationData: locationData,
                            onClose: {
                                withAnimation {
                                    selectedContact = nil
                                }
                            }
                        )
                        .padding(.horizontal, 24)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    }
                }

                // Contact Carousel positioned at bottom
                VStack {
                    Spacer()
                    ContactCarousel(
                        showContactGlobe: $showContactGlobe,
                        contactForGlobe: $contactForGlobe,
                        contactLocationToNavigate: $contactLocationToNavigate,
                        showAddConnection: $showAddConnection
                    )
                    .padding(.bottom, 20)  // Add some padding from bottom edge
                }
            }
        }
    }

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                mapAnnotations
            }
            .mapStyle(
                .hybrid(
                    elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false)
            )
            .mapControls {
                // Empty - removes default controls
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupInitialGlobeView()
            waypointsManager.loadWaypoints()

            // Refresh current location to ensure we have the latest
            locationManager.refreshCurrentLocation()

            // Load media for waypoints when they're loaded
            Task {
                await MediaService.shared.loadMediaForWaypoints(waypointsManager.waypoints)
            }

            // Animate route paths after waypoints load
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    routePathAnimation = 1.0
                }
            }
        }
        .onChange(of: contactLocationToNavigate) { _, newLocation in
            if let wrapper = newLocation {
                navigateToLocation(wrapper.coordinate)
                // Clear the navigation request after navigating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    contactLocationToNavigate = nil
                }
            }
        }
        .onChange(of: waypointsManager.waypoints) { _, newWaypoints in
            // Load media for new waypoints
            Task {
                await MediaService.shared.loadMediaForWaypoints(newWaypoints)
            }

            // Re-animate when waypoints change
            routePathAnimation = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    routePathAnimation = 1.0
                }
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
                if locationManager.knownLocation != nil || locationManager.actualLocation != nil {
                    centerOnUserLocation()
                }
            }
        }
    }

    private func centerOnUserLocation() {
        // Try known location first, then actual location, then show picker
        let location: CLLocationCoordinate2D

        if let knownLocation = locationManager.knownLocation {
            location = knownLocation
            print("📍 Centering on known location: \(location.latitude), \(location.longitude)")
        } else if let actualLocation = locationManager.actualLocation {
            // Use actual location if no known location is set yet
            location = actualLocation.coordinate
            print("📍 Centering on actual location: \(location.latitude), \(location.longitude)")
        } else {
            // No location available, show picker
            print("📍 No location available, showing picker")
            showLocationPicker = true
            return
        }

        withAnimation(.interpolatingSpring(stiffness: 80, damping: 15)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 1_500_000,  // 1,500km altitude
                    heading: 0,
                    pitch: 65  // Angled view for 3D effect
                )
            )
        }
    }

    private func showFullGlobe() {
        withAnimation(.interpolatingSpring(stiffness: 60, damping: 12)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    distance: 20_000_000,  // 20,000km altitude - see full globe
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

    func navigateToLocation(_ coordinate: CLLocationCoordinate2D, distance: Double = 500_000) {
        withAnimation(.interpolatingSpring(stiffness: 80, damping: 15)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: distance,  // Default 500km altitude
                    heading: 0,
                    pitch: 65  // Angled view for 3D effect
                )
            )
        }
    }

    private func routeGradient(for routeId: UUID) -> LinearGradient {
        // Generate a consistent color based on the route ID
        let hashValue = routeId.hashValue
        let hue = Double(abs(hashValue) % 360) / 360.0

        // Create gradient colors based on the hue
        let color1 = Color(hue: hue, saturation: 0.8, brightness: 0.9)
        let color2 = Color(hue: hue, saturation: 0.6, brightness: 0.7)

        return LinearGradient(
            colors: [color1, color2],
            startPoint: .leading,
            endPoint: .trailing
        )
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

    private func addWaypointAtCurrentLocation() {
        // Check location permission first
        switch locationManager.currentAuthorizationStatus {
        case .notDetermined:
            // Request permission
            locationManager.requestLocationPermission { granted in
                if granted {
                    // Try again after permission granted
                    self.addWaypointAtCurrentLocation()
                } else {
                    self.showLocationDeniedAlert = true
                }
            }
            return
        case .denied, .restricted:
            showLocationDeniedAlert = true
            return
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }

        Task {
            do {
                // Get current location
                guard let currentLocation = locationManager.actualLocation else {
                    print("📍 No current location available for waypoint creation")
                    // Try to start location updates if not already started
                    await MainActor.run {
                        showLocationPermissionAlert = true
                    }
                    return
                }

                print(
                    "📍 Creating waypoint at current location: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)"
                )

                // Generate waypoint name based on current location and date
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                let dateString = formatter.string(from: Date())

                // Get city name from reverse geocoding
                let geocoder = CLGeocoder()
                var waypointName = "Waypoint - \(dateString)"

                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(currentLocation)
                    if let placemark = placemarks.first {
                        let city = placemark.locality ?? placemark.name ?? "Unknown Location"
                        waypointName = "\(city) - \(dateString)"
                    }
                } catch {
                    print("Geocoding error: \(error)")
                }

                // Create waypoint at actual location
                let newWaypoint = try await waypointsManager.createWaypoint(
                    name: waypointName,
                    location: currentLocation.coordinate
                )

                await MainActor.run {
                    // Select the newly created waypoint
                    selectedWaypoint = newWaypoint

                    // Center map on the new waypoint
                    if let coordinate = newWaypoint.coordinate {
                        withAnimation(.interpolatingSpring(stiffness: 80, damping: 15)) {
                            cameraPosition = .camera(
                                MapCamera(
                                    centerCoordinate: coordinate,
                                    distance: 500_000,  // 500km altitude
                                    heading: 0,
                                    pitch: 65
                                )
                            )
                        }
                    }

                    // Show the waypoint details for editing
                    showWaypointDetails = true
                }
            } catch {
                print("Error creating waypoint: \(error)")
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
                                isUser ? Color.blue : Color.orange,
                                isUser ? Color.cyan : Color.pink,
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
                            isUser ? Color.cyan : Color.pink,
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
                .shadow(color: isUser ? .blue : .orange, radius: 10)
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
                colors: [Color.blue, Color.cyan],
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
                                        Color.white.opacity(0.05),
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
                                Color.white.opacity(0.1),
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
                                    Color.white.opacity(0.02),
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
                            Color.white.opacity(0.1),
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
                    .fill(
                        connection.hasAccount
                            ? LinearGradient(
                                colors: [.blue, .cyan], startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [.orange, .yellow], startPoint: .topLeading,
                                endPoint: .bottomTrailing)
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
                                    Color.white.opacity(0.02),
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
                            Color.white.opacity(0.1),
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
    @StateObject private var mediaService = MediaService.shared
    @State private var thumbnailImage: UIImage?

    var mediaCount: Int {
        mediaService.waypointMediaCounts[waypoint.id] ?? 0
    }

    var thumbnailURL: String? {
        mediaService.waypointThumbnails[waypoint.id]
    }

    var body: some View {
        ZStack {
            if mediaCount > 0 && thumbnailURL != nil {
                // Media thumbnail marker
                ZStack(alignment: .topTrailing) {
                    // Thumbnail image
                    AsyncImage(url: URL(string: thumbnailURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: isSelected ? 60 : 40, height: isSelected ? 60 : 40
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white, .white.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        case .empty, .failure:
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .cyan.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(
                                    width: isSelected ? 60 : 40, height: isSelected ? 60 : 40
                                )
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: isSelected ? 20 : 14))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white, .white.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        @unknown default:
                            EmptyView()
                        }
                    }

                    // Media count badge
                    if mediaCount > 1 {
                        Text("\(mediaCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.red)
                            )
                            .offset(x: 5, y: -5)
                    }
                }
            } else {
                // Default waypoint marker (no media)
                ZStack {
                    // Outer ring with animation
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.cyan.opacity(0.3),
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
                                colors: [.blue, .cyan],
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
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mediaCount)
        .task {
            await mediaService.loadMediaCount(for: waypoint.id)
            await mediaService.loadThumbnail(for: waypoint.id)
        }
    }
}

// MARK: - Waypoint Info Card
struct WaypointInfoCard: View {
    let waypoint: Waypoint
    let onClose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMedia: () -> Void

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        if let arrival = waypoint.arrivalTime, let departure = waypoint.departureTime {
            if Calendar.current.isDate(arrival, inSameDayAs: departure) {
                return formatter.string(from: arrival)
            } else {
                let endFormatter = DateFormatter()
                endFormatter.dateFormat =
                    Calendar.current.component(.year, from: arrival)
                        == Calendar.current.component(.year, from: departure)
                    ? "MMM d" : "MMM d, yyyy"
                return
                    "\(formatter.string(from: arrival)) - \(endFormatter.string(from: departure))"
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

                    Text(
                        [waypoint.areaCode, city, waypoint.country]
                            .compactMap { $0 }
                            .joined(separator: ", ")
                    )
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onMedia) {
                    HStack {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 12))
                        Text("Media")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.3))
                    )
                }

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
                                    Color.white.opacity(0.02),
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
                            Color.white.opacity(0.1),
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
