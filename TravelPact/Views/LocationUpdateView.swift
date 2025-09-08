import SwiftUI
import CoreLocation

struct LocationUpdateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationPrivacyManager.shared
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var isUpdating = false
    @State private var selectedAccuracy: LocationAccuracy = .city
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "location.north.line.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .white.opacity(0.3), radius: 10)
                        
                        Text("Update Your Location")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Choose how precisely to share your location")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Location Options
                    VStack(spacing: 16) {
                        // Use Current Location
                        if locationManager.isLocationEnabled {
                            Button(action: useCurrentLocation) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 20))
                                    Text("Use Current Location")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Spacer()
                                    if let actual = locationManager.actualLocation {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.1))
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.ultraThinMaterial)
                                        )
                                )
                            }
                        }
                        
                        // Manual Location Entry
                        NavigationLink(destination: LocationSearchView { coordinate, name in
                            selectedLocation = coordinate
                            locationName = name
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                Text("Search for Location")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Spacer()
                                if selectedLocation != nil {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(locationName)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.8))
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Location Accuracy Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location Accuracy")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 24)
                        
                        HStack(spacing: 12) {
                            ForEach(LocationAccuracy.allCases, id: \.self) { accuracy in
                                AccuracyOption(
                                    accuracy: accuracy,
                                    isSelected: selectedAccuracy == accuracy,
                                    action: {
                                        selectedAccuracy = accuracy
                                        locationManager.locationAccuracy = accuracy
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Current Location Display
                    if let knownLocation = locationManager.knownLocation {
                        VStack(spacing: 8) {
                            Text("Current Known Location")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(locationManager.knownLocationName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal, 24)
                    }
                    
                    // Update Button
                    Button(action: updateLocation) {
                        HStack {
                            if isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Update Location")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                    .padding(.horizontal, 24)
                    .disabled(selectedLocation == nil && locationManager.actualLocation == nil)
                    .disabled(isUpdating)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func useCurrentLocation() {
        guard let actual = locationManager.actualLocation else { return }
        
        selectedLocation = actual.coordinate
        
        // Reverse geocode to get location name
        locationManager.reverseGeocode(location: actual) { name in
            locationName = name
        }
    }
    
    private func updateLocation() {
        guard let location = selectedLocation ?? locationManager.actualLocation?.coordinate else { return }
        
        isUpdating = true
        
        // Update the known location
        if locationName.isEmpty && locationManager.actualLocation != nil {
            locationManager.reverseGeocode(location: locationManager.actualLocation!) { name in
                locationManager.updateKnownLocation(coordinate: location, name: name)
                dismiss()
            }
        } else {
            locationManager.updateKnownLocation(coordinate: location, name: locationName)
            dismiss()
        }
    }
}

struct AccuracyOption: View {
    let accuracy: LocationAccuracy
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Text(accuracy.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
    }
    
    private var iconName: String {
        switch accuracy {
        case .city:
            return "building.2.crop.circle"
        case .region:
            return "map.circle"
        case .country:
            return "globe"
        }
    }
}