import Foundation
import CoreLocation
import Combine

enum LocationAccuracy: String, CaseIterable {
    case city = "city"
    case region = "region"
    case country = "country"
    
    var displayName: String {
        switch self {
        case .city: return "City"
        case .region: return "Region"
        case .country: return "Country"
        }
    }
    
    var coordinateAccuracy: Double {
        switch self {
        case .city: return 0.01 // ~1km precision
        case .region: return 0.1 // ~10km precision
        case .country: return 1.0 // ~100km precision
        }
    }
}

class LocationPrivacyManager: NSObject, ObservableObject {
    static let shared = LocationPrivacyManager()
    
    // Published properties for UI binding
    @Published var actualLocation: CLLocation?
    @Published var knownLocation: CLLocationCoordinate2D?
    @Published var knownLocationName: String = ""
    @Published var locationAccuracy: LocationAccuracy = .city
    @Published var showTravelSuggestion = false
    @Published var travelDistance: Double = 0
    @Published var isLocationEnabled = false
    @Published var lastKnownLocationUpdate: Date?
    
    // Core Location
    private let locationManager = CLLocationManager()
    private var lastSuggestionLocation: CLLocation?
    private let travelThresholdKM: Double = 100.0
    
    // User defaults keys
    private let knownLocationKey = "TravelPact.KnownLocation"
    private let knownLocationNameKey = "TravelPact.KnownLocationName"
    private let locationAccuracyKey = "TravelPact.LocationAccuracy"
    private let lastUpdateKey = "TravelPact.LastLocationUpdate"
    
    override init() {
        super.init()
        setupLocationManager()
        loadStoredKnownLocation()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1000 // Update every 1km
        locationManager.allowsBackgroundLocationUpdates = false
        
        // Check current authorization status
        checkLocationAuthorization()
    }
    
    private func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isLocationEnabled = false
        case .authorizedAlways, .authorizedWhenInUse:
            isLocationEnabled = true
            locationManager.startUpdatingLocation()
        @unknown default:
            isLocationEnabled = false
        }
    }
    
    // MARK: - Known Location Management
    
    func updateKnownLocation(coordinate: CLLocationCoordinate2D, name: String) {
        knownLocation = coordinate
        knownLocationName = name
        lastKnownLocationUpdate = Date()
        showTravelSuggestion = false
        lastSuggestionLocation = actualLocation
        
        // Store locally
        saveKnownLocation()
        
        // Update in database
        Task {
            await syncKnownLocationToDatabase()
        }
    }
    
    private func saveKnownLocation() {
        guard let location = knownLocation else { return }
        
        let locationDict: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "name": knownLocationName,
            "accuracy": locationAccuracy.rawValue,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        UserDefaults.standard.set(locationDict, forKey: knownLocationKey)
        UserDefaults.standard.set(knownLocationName, forKey: knownLocationNameKey)
        UserDefaults.standard.set(locationAccuracy.rawValue, forKey: locationAccuracyKey)
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
    }
    
    private func loadStoredKnownLocation() {
        if let locationDict = UserDefaults.standard.dictionary(forKey: knownLocationKey),
           let latitude = locationDict["latitude"] as? Double,
           let longitude = locationDict["longitude"] as? Double {
            knownLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        knownLocationName = UserDefaults.standard.string(forKey: knownLocationNameKey) ?? ""
        
        if let accuracyString = UserDefaults.standard.string(forKey: locationAccuracyKey),
           let accuracy = LocationAccuracy(rawValue: accuracyString) {
            locationAccuracy = accuracy
        }
        
        lastKnownLocationUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
    }
    
    // MARK: - Travel Detection
    
    private func checkForTravel() {
        guard let actual = actualLocation,
              let known = knownLocation,
              !showTravelSuggestion else { return }
        
        let knownCLLocation = CLLocation(latitude: known.latitude, longitude: known.longitude)
        let distance = actual.distance(from: knownCLLocation) / 1000 // Convert to km
        
        travelDistance = distance
        
        // Check if we should show suggestion
        if distance >= travelThresholdKM {
            // Only show if we haven't already suggested for this location
            if lastSuggestionLocation == nil ||
               actual.distance(from: lastSuggestionLocation!) > 10000 { // 10km buffer
                showTravelSuggestion = true
                lastSuggestionLocation = actual
            }
        }
    }
    
    func dismissTravelSuggestion() {
        showTravelSuggestion = false
        lastSuggestionLocation = actualLocation
    }
    
    // MARK: - Location Obfuscation
    
    func obfuscateLocation(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let precision = locationAccuracy.coordinateAccuracy
        
        // Round coordinates to reduce precision based on accuracy setting
        let lat = round(coordinate.latitude / precision) * precision
        let lon = round(coordinate.longitude / precision) * precision
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Database Sync
    
    private func syncKnownLocationToDatabase() async {
        guard let location = knownLocation else { return }
        
        do {
            let session = try await SupabaseManager.shared.auth.session
            let obfuscatedLocation = obfuscateLocation(location)
            
            struct LocationUpdate: Codable {
                let known_location: LocationData
                let known_location_name: String
                let location_accuracy: String
                let location_updated_at: String
                let updated_at: String
            }
            
            let locationData = LocationData(
                latitude: obfuscatedLocation.latitude,
                longitude: obfuscatedLocation.longitude,
                address: knownLocationName,
                city: nil,
                country: nil
            )
            
            let update = LocationUpdate(
                known_location: locationData,
                known_location_name: knownLocationName,
                location_accuracy: locationAccuracy.rawValue,
                location_updated_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await SupabaseManager.shared.client
                .from("profiles")
                .update(update)
                .eq("id", value: session.user.id.uuidString)
                .execute()
            
            print("✅ Known location synced to database")
        } catch {
            print("❌ Failed to sync known location: \(error)")
        }
    }
    
    // MARK: - Geocoding
    
    func reverseGeocode(location: CLLocation, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else {
                completion("Unknown Location")
                return
            }
            
            var components: [String] = []
            
            switch self.locationAccuracy {
            case .city:
                if let city = placemark.locality {
                    components.append(city)
                }
                if let country = placemark.country {
                    components.append(country)
                }
            case .region:
                if let region = placemark.administrativeArea {
                    components.append(region)
                }
                if let country = placemark.country {
                    components.append(country)
                }
            case .country:
                if let country = placemark.country {
                    components.append(country)
                }
            }
            
            let locationName = components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
            completion(locationName)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationPrivacyManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update actual location (kept private, never sent to server)
        actualLocation = location
        
        // Check for significant travel
        checkForTravel()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
}