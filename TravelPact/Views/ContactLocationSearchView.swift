import SwiftUI
import MapKit

struct ContactLocationSearchView: View {
    let contact: TravelPactContact
    @Binding var isPresented: Bool
    var onLocationAssigned: ((CLLocationCoordinate2D) -> Void)?

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var locationManager = ContactLocationManager.shared
    @StateObject private var waypointsManager = WaypointsManager()
    @FocusState private var searchFieldFocused: Bool

    // Get recent waypoint cities from user's travel history
    private var recentCities: [(String, CLLocationCoordinate2D)] {
        var cities: [(String, CLLocationCoordinate2D)] = []
        var addedCities = Set<String>()

        // Get unique cities from user's waypoints, most recent first
        for waypoint in waypointsManager.waypoints.reversed() {
            // Use city name if available, otherwise use waypoint name
            let cityName = waypoint.city ?? waypoint.name
            if !addedCities.contains(cityName),
               cities.count < 8,
               let coordinate = waypoint.coordinate {
                addedCities.insert(cityName)
                cities.append((cityName, coordinate))
            }
        }

        // If user has fewer than 8 waypoints, add some popular fallbacks
        if cities.count < 8 {
            let fallbackCities = [
                ("New York", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
                ("London", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
                ("Paris", CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
                ("Tokyo", CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
                ("Los Angeles", CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
                ("Berlin", CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)),
                ("Sydney", CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
                ("Singapore", CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198))
            ]

            for city in fallbackCities {
                if !addedCities.contains(city.0) && cities.count < 8 {
                    cities.append(city)
                    addedCities.insert(city.0)
                }
            }
        }

        return cities
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Simple round search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
                
                TextField("Where is \(contact.name)?", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .medium))
                    .focused($searchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { _, newValue in
                        // Cancel previous search task
                        searchTask?.cancel()
                        
                        if newValue.isEmpty {
                            searchResults = []
                        } else if newValue.count > 2 {
                            // Debounced search after user stops typing
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                if !Task.isCancelled {
                                    performSearch()
                                }
                            }
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 14))
                    }
                }
                
                // Close button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            
            // Recent/Popular cities (show when not searching and no results)
            if searchText.isEmpty && searchResults.isEmpty && !isSearching {
                VStack(alignment: .leading, spacing: 12) {
                    Text(waypointsManager.waypoints.isEmpty ? "Popular Cities" : "Recent Locations")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                        ForEach(recentCities, id: \.0) { city in
                            Button(action: {
                                assignPopularCity(coordinate: city.1, name: city.0)
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.orange)
                                        )
                                    
                                    Text(city.0)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
            
            // Search results (only show when there are results)
            if !searchResults.isEmpty || isSearching {
                ScrollView {
                    VStack(spacing: 6) {
                        if isSearching {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                                Text("Searching...")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 13))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            // Clean search results list
                            ForEach(searchResults.prefix(5), id: \.self) { item in
                                LocationResultRow(
                                    mapItem: item,
                                    isSelected: selectedLocation == item,
                                    onTap: {
                                        selectedLocation = item
                                        assignLocation(item)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8) // Small padding from keyboard
        .onAppear {
            // Auto-focus the search field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                searchFieldFocused = true
            }
            // Load waypoints for recent cities
            waypointsManager.loadWaypoints()
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            searchResults = []
            return 
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        // Add region to improve search results
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let response = response {
                    // Sort by relevance and limit results
                    searchResults = Array(response.mapItems.prefix(10))
                } else {
                    searchResults = []
                    if let error = error {
                        print("❌ Search error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func assignLocation(_ mapItem: MKMapItem) {
        let locationData = ContactLocationData(
            locationName: mapItem.name ?? "Unknown Location",
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude,
            address: formatAddress(from: mapItem.placemark),
            city: mapItem.placemark.locality,
            country: mapItem.placemark.country
        )
        
        if let contactId = contact.contactIdentifier {
            locationManager.assignLocation(to: contactId, location: locationData)
        }
        
        // Navigate to the assigned location
        onLocationAssigned?(mapItem.placemark.coordinate)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
    
    private func assignPopularCity(coordinate: CLLocationCoordinate2D, name: String) {
        let locationData = ContactLocationData(
            locationName: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: name,
            city: name,
            country: nil
        )
        
        if let contactId = contact.contactIdentifier {
            locationManager.assignLocation(to: contactId, location: locationData)
        }
        
        // Navigate to the assigned location
        onLocationAssigned?(coordinate)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var addressParts: [String] = []
        
        if let street = placemark.thoroughfare {
            addressParts.append(street)
        }
        if let city = placemark.locality {
            addressParts.append(city)
        }
        if let state = placemark.administrativeArea {
            addressParts.append(state)
        }
        if let country = placemark.country {
            addressParts.append(country)
        }
        
        return addressParts.joined(separator: ", ")
    }
}

// MARK: - Location Result Row

struct LocationResultRow: View {
    let mapItem: MKMapItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Clean location icon
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    )
                
                // Location details
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let address = formatSubtitle() {
                        Text(address)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Subtle chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.03))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatSubtitle() -> String? {
        var parts: [String] = []
        
        if let city = mapItem.placemark.locality {
            parts.append(city)
        }
        if let state = mapItem.placemark.administrativeArea {
            parts.append(state)
        }
        if let country = mapItem.placemark.country {
            parts.append(country)
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}