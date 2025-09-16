import SwiftUI
import MapKit
import CoreLocation

struct BulkLocationAssignmentView: View {
    let contacts: [TravelPactContact]
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @StateObject private var locationManager = ContactLocationManager.shared
    @FocusState private var searchFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    // Popular cities for quick selection
    private let popularCities = [
        ("New York", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        ("London", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
        ("Paris", CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
        ("Tokyo", CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
        ("Sydney", CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
        ("Los Angeles", CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
        ("Berlin", CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)),
        ("Singapore", CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198))
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Glass background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .background(
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                    )
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Assign Location to \(contacts.count) Contacts")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(contacts.prefix(6), id: \.id) { contact in
                                    ContactInitialsBubble(
                                        initials: contact.bubbleInitials,
                                        hasAccount: contact.hasAccount,
                                        hasLocation: false
                                    )
                                    .frame(width: 36, height: 36)
                                }
                                
                                if contacts.count > 6 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        
                                        Text("+\(contacts.count - 6)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Search bar
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 16))
                            
                            TextField("Search for a city or location...", text: $searchText)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .focused($searchFieldFocused)
                                .onSubmit {
                                    performSearch()
                                }
                                .onChange(of: searchText) { _, newValue in
                                    searchTask?.cancel()
                                    
                                    if newValue.isEmpty {
                                        searchResults = []
                                    } else if newValue.count > 2 {
                                        searchTask = Task {
                                            try? await Task.sleep(nanoseconds: 300_000_000)
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        
                        // Popular cities (show when not searching)
                        if searchText.isEmpty && searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Popular Cities")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 4)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                    ForEach(popularCities, id: \.0) { city in
                                        Button(action: {
                                            assignLocationToAllContacts(
                                                coordinate: city.1,
                                                name: city.0
                                            )
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.orange)
                                                
                                                Text(city.0)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.white.opacity(0.05))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    
                    // Search results
                    if !searchResults.isEmpty || isSearching {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Search Results")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 8)
                            
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
                                        ForEach(searchResults.prefix(8), id: \.self) { item in
                                            BulkLocationResultRow(
                                                mapItem: item,
                                                onTap: {
                                                    assignLocationToAllContacts(
                                                        coordinate: item.placemark.coordinate,
                                                        mapItem: item
                                                    )
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                            .frame(maxHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Bulk Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    searchFieldFocused = true
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let response = response {
                    searchResults = Array(response.mapItems.prefix(15))
                } else {
                    searchResults = []
                    if let error = error {
                        print("❌ Bulk search error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func assignLocationToAllContacts(coordinate: CLLocationCoordinate2D, name: String) {
        let locationData = ContactLocationData(
            locationName: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: name,
            city: name,
            country: nil
        )
        
        assignLocationData(locationData)
    }
    
    private func assignLocationToAllContacts(coordinate: CLLocationCoordinate2D, mapItem: MKMapItem) {
        let locationData = ContactLocationData(
            locationName: mapItem.name ?? "Unknown Location",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: formatAddress(from: mapItem.placemark),
            city: mapItem.placemark.locality,
            country: mapItem.placemark.country
        )
        
        assignLocationData(locationData)
    }
    
    private func assignLocationData(_ locationData: ContactLocationData) {
        // Assign the location to all selected contacts
        for contact in contacts {
            if let contactId = contact.contactIdentifier {
                locationManager.assignLocation(to: contactId, location: locationData)
            }
        }
        
        // Dismiss the view
        onComplete?()
        dismiss()
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var addressParts: [String] = []
        
        if let name = placemark.name {
            addressParts.append(name)
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

// MARK: - Bulk Location Result Row
struct BulkLocationResultRow: View {
    let mapItem: MKMapItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let subtitle = formatSubtitle() {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.orange.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
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