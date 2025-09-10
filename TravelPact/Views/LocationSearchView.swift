import SwiftUI
import MapKit
import CoreLocation

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationPrivacyManager.shared
    @State private var searchText = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName = ""
    @State private var isSearching = false
    
    let onLocationSelected: (CLLocationCoordinate2D, String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map View
                Map(
                    coordinateRegion: $region,
                    showsUserLocation: true,
                    annotationItems: selectedCoordinate != nil ? [LocationPin(coordinate: selectedCoordinate!)] : []
                ) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .blue)
                }
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    // Center on user's actual location if available
                    if let actualLocation = locationManager.actualLocation {
                        region = MKCoordinateRegion(
                            center: actualLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        )
                    } else if let knownLocation = locationManager.knownLocation {
                        region = MKCoordinateRegion(
                            center: knownLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        )
                    }
                }
                
                // Crosshair in center
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .thin))
                    .foregroundColor(.blue)
                
                // Controls Overlay
                VStack {
                    // Search Bar
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search location...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .onSubmit {
                                    searchLocation()
                                }
                            
                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding()
                        
                        if !selectedLocationName.isEmpty {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.blue)
                                Text(selectedLocationName)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                        }
                    }
                    .background(Color(.systemBackground).opacity(0.95))
                    
                    Spacer()
                    
                    // Location Controls
                    VStack(spacing: 12) {
                        // Current Location Button
                        HStack {
                            Spacer()
                            Button(action: centerOnUserLocation) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.blue))
                                    .shadow(radius: 5)
                            }
                            .padding(.trailing)
                        }
                        
                        // Select Location Button
                        Button(action: selectCurrentLocation) {
                            Text("Select This Location")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue)
                                )
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitle("Choose Location", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .onAppear {
            centerOnUserLocation()
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        searchRequest.region = region
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            isSearching = false
            
            guard let response = response,
                  let item = response.mapItems.first else {
                return
            }
            
            // Update region to show search result
            withAnimation {
                region = MKCoordinateRegion(
                    center: item.placemark.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
            
            // Set selected location
            selectedCoordinate = item.placemark.coordinate
            
            // Build location name
            var nameComponents: [String] = []
            if let name = item.name {
                nameComponents.append(name)
            }
            if let city = item.placemark.locality {
                nameComponents.append(city)
            }
            if let country = item.placemark.country {
                nameComponents.append(country)
            }
            
            selectedLocationName = nameComponents.joined(separator: ", ")
        }
    }
    
    private func centerOnUserLocation() {
        let locationManager = CLLocationManager()
        
        if let location = locationManager.location {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
    
    private func selectCurrentLocation() {
        let coordinate = region.center
        
        // Reverse geocode if no name is set
        if selectedLocationName.isEmpty {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                var nameComponents: [String] = []
                
                if let placemark = placemarks?.first {
                    if let city = placemark.locality {
                        nameComponents.append(city)
                    }
                    if let country = placemark.country {
                        nameComponents.append(country)
                    }
                }
                
                let name = nameComponents.isEmpty ? "Selected Location" : nameComponents.joined(separator: ", ")
                
                onLocationSelected(coordinate, name)
                dismiss()
            }
        } else {
            onLocationSelected(coordinate, selectedLocationName)
            dismiss()
        }
    }
}

struct LocationPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}