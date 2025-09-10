import SwiftUI
import MapKit
import CoreLocation

// MARK: - Contact Globe View
struct ContactGlobeView: View {
    let contact: TravelPactContact
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactDataService = ContactDataService()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedRouteIndex = 0
    @State private var selectedWaypointIndex = 0
    @State private var showContactCard = true
    @State private var routePathAnimation: Double = 0
    
    var currentRoute: ContactRoute? {
        guard !contactDataService.routes.isEmpty,
              selectedRouteIndex < contactDataService.routes.count else { return nil }
        return contactDataService.routes[selectedRouteIndex]
    }
    
    var currentWaypoint: ContactWaypoint? {
        guard let route = currentRoute,
              !route.waypoints.isEmpty,
              selectedWaypointIndex < route.waypoints.count else { return nil }
        return route.waypoints[selectedWaypointIndex]
    }
    
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        if let route = currentRoute {
            routeMapContent(route)
        }
    }
    
    @MapContentBuilder
    private func routeMapContent(_ route: ContactRoute) -> some MapContent {
        
        // Route path
        if route.waypoints.count > 1 {
            let coordinates = route.waypoints.compactMap { waypoint in
                CLLocationCoordinate2D(
                    latitude: waypoint.location.latitude,
                    longitude: waypoint.location.longitude
                )
            }
            
            if coordinates.count > 1 {
                MapPolyline(coordinates: coordinates)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ).opacity(routePathAnimation),
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        
        // Waypoint markers
        ForEach(Array(route.waypoints.enumerated()), id: \.offset) { index, waypoint in
            let coordinate = CLLocationCoordinate2D(
                latitude: waypoint.location.latitude,
                longitude: waypoint.location.longitude
            )
            
            Annotation("", coordinate: coordinate) {
                ContactWaypointMarker(
                    waypoint: waypoint,
                    isSelected: index == selectedWaypointIndex,
                    isCurrent: index == selectedWaypointIndex
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedWaypointIndex = index
                        focusOnWaypoint(waypoint)
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Map
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
            
            // Gradient overlays
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.4), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .ignoresSafeArea()
                
                Spacer()
                
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea()
            }
            .allowsHitTesting(false)
            
            // UI Layer
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: { withAnimation { showContactCard.toggle() } }) {
                        Image(systemName: showContactCard ? "person.circle.fill" : "person.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                    )
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Contact card
                if showContactCard {
                    ContactInfoOverlay(
                        contact: contact,
                        currentWaypoint: currentWaypoint
                    )
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // Navigation controls
                if !contactDataService.routes.isEmpty {
                    RouteNavigationControls(
                        routes: contactDataService.routes,
                        selectedRouteIndex: $selectedRouteIndex,
                        selectedWaypointIndex: $selectedWaypointIndex,
                        onRouteChanged: { routeIndex in
                            selectedWaypointIndex = 0
                            if let firstWaypoint = contactDataService.routes[routeIndex].waypoints.first {
                                focusOnWaypoint(firstWaypoint)
                            }
                        },
                        onWaypointChanged: { waypointIndex in
                            if let waypoint = currentRoute?.waypoints[safe: waypointIndex] {
                                focusOnWaypoint(waypoint)
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            
            // Loading overlay
            if contactDataService.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("Loading \(contact.displayName)'s journeys...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.1))
                            )
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if let userId = contact.userId {
                await contactDataService.loadContactData(userId: userId)
                
                // Focus on latest waypoint initially
                if let latestWaypoint = contactDataService.routes.first?.waypoints.first {
                    focusOnWaypoint(latestWaypoint)
                    
                    // Animate route path
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            routePathAnimation = 1.0
                        }
                    }
                }
            }
        }
        .onChange(of: selectedRouteIndex) { _, newValue in
            // Re-animate route path when route changes
            routePathAnimation = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    routePathAnimation = 1.0
                }
            }
        }
    }
    
    private func focusOnWaypoint(_ waypoint: ContactWaypoint) {
        let coordinate = CLLocationCoordinate2D(
            latitude: waypoint.location.latitude,
            longitude: waypoint.location.longitude
        )
        
        withAnimation(.interpolatingSpring(stiffness: 80, damping: 15)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: 1_000_000, // 1,000km altitude
                    heading: 0,
                    pitch: 60
                )
            )
        }
    }
}

// MARK: - Contact Info Overlay
struct ContactInfoOverlay: View {
    let contact: TravelPactContact
    let currentWaypoint: ContactWaypoint?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Contact photo/initials
                if let photoURL = contact.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.blue, Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                        case .empty, .failure:
                            ContactInitialsBubble(
                                initials: contact.bubbleInitials,
                                hasAccount: contact.hasAccount
                            )
                            .frame(width: 60, height: 60)
                        @unknown default:
                            ContactInitialsBubble(
                                initials: contact.bubbleInitials,
                                hasAccount: contact.hasAccount
                            )
                            .frame(width: 60, height: 60)
                        }
                    }
                } else {
                    ContactInitialsBubble(
                        initials: contact.bubbleInitials,
                        hasAccount: contact.hasAccount
                    )
                    .frame(width: 60, height: 60)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let waypoint = currentWaypoint {
                        Text("At \(waypoint.name)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                ContactActionButton(
                    icon: "phone.fill",
                    title: "Call",
                    color: .green
                ) {
                    // Handle call
                    if let phone = contact.phoneNumber {
                        if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                ContactActionButton(
                    icon: "message.fill",
                    title: "Message",
                    color: .blue
                ) {
                    // Handle message
                    if let phone = contact.phoneNumber {
                        if let url = URL(string: "sms:\(phone.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                ContactActionButton(
                    icon: "globe",
                    title: "Social",
                    color: .purple
                ) {
                    // Handle social links - could open profile or social media
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
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Contact Action Button
struct ContactActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.3))
                    )
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Route Navigation Controls
struct RouteNavigationControls: View {
    let routes: [ContactRoute]
    @Binding var selectedRouteIndex: Int
    @Binding var selectedWaypointIndex: Int
    let onRouteChanged: (Int) -> Void
    let onWaypointChanged: (Int) -> Void
    
    var currentRoute: ContactRoute? {
        guard !routes.isEmpty, selectedRouteIndex < routes.count else { return nil }
        return routes[selectedRouteIndex]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Route selector
            if routes.count > 1 {
                HStack {
                    Text("Route")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: previousRoute) {
                            Image(systemName: "chevron.left.2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .disabled(selectedRouteIndex == 0)
                        
                        Text("\(selectedRouteIndex + 1) of \(routes.count)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Button(action: nextRoute) {
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .disabled(selectedRouteIndex >= routes.count - 1)
                    }
                }
            }
            
            // Waypoint navigation
            if let route = currentRoute, route.waypoints.count > 1 {
                HStack {
                    Text(route.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: previousWaypoint) {
                            Image(systemName: "chevron.left.2")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .disabled(selectedWaypointIndex == 0)
                        
                        Button(action: previousWaypoint) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .disabled(selectedWaypointIndex == 0)
                        
                        Text("\(selectedWaypointIndex + 1)/\(route.waypoints.count)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(minWidth: 40)
                        
                        Button(action: nextWaypoint) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .disabled(selectedWaypointIndex >= route.waypoints.count - 1)
                        
                        Button(action: nextWaypoint) {
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .disabled(selectedWaypointIndex >= route.waypoints.count - 1)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private func previousRoute() {
        guard selectedRouteIndex > 0 else { return }
        selectedRouteIndex -= 1
        onRouteChanged(selectedRouteIndex)
    }
    
    private func nextRoute() {
        guard selectedRouteIndex < routes.count - 1 else { return }
        selectedRouteIndex += 1
        onRouteChanged(selectedRouteIndex)
    }
    
    private func previousWaypoint() {
        guard selectedWaypointIndex > 0 else { return }
        selectedWaypointIndex -= 1
        onWaypointChanged(selectedWaypointIndex)
    }
    
    private func nextWaypoint() {
        guard let route = currentRoute,
              selectedWaypointIndex < route.waypoints.count - 1 else { return }
        selectedWaypointIndex += 1
        onWaypointChanged(selectedWaypointIndex)
    }
}

// MARK: - Contact Waypoint Marker
struct ContactWaypointMarker: View {
    let waypoint: ContactWaypoint
    let isSelected: Bool
    let isCurrent: Bool
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)],
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
            Image(systemName: isCurrent ? "person.fill" : "mappin")
                .font(.system(size: isSelected ? 12 : 8, weight: .bold))
                .foregroundColor(.white)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Helper Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}