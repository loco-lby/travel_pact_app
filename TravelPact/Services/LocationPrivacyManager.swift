import Foundation
import CoreLocation
import Combine
import UserNotifications
import UIKit


class LocationPrivacyManager: NSObject, ObservableObject {
    static let shared = LocationPrivacyManager()
    
    // Published properties for UI binding
    @Published var actualLocation: CLLocation?
    @Published var knownLocation: CLLocationCoordinate2D?
    @Published var knownLocationName: String = ""
    @Published var showTravelSuggestion = false
    @Published var travelDistance: Double = 0
    @Published var isLocationEnabled = false
    @Published var lastKnownLocationUpdate: Date?
    @Published var currentAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Core Location
    private let locationManager = CLLocationManager()
    private var lastSuggestionLocation: CLLocation?
    private let travelThresholdKM: Double = 100.0
    private var locationPermissionCompletion: ((Bool) -> Void)?
    private var alwaysAuthorizationCompletion: ((Bool) -> Void)?
    
    // Movement detection threshold - 1km
    private let movementThreshold: Double = 1.0
    
    // User defaults keys
    private let knownLocationKey = "TravelPact.KnownLocation"
    private let knownLocationNameKey = "TravelPact.KnownLocationName"
    private let lastUpdateKey = "TravelPact.LastLocationUpdate"
    
    override init() {
        super.init()
        setupLocationManager()
        loadStoredKnownLocation()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        updateDistanceFilter()
        
        // Only enable background updates if we have Always authorization
        // This prevents the crash when background modes aren't properly configured
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.showsBackgroundLocationIndicator = true
        } else {
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.pausesLocationUpdatesAutomatically = true
        }
        
        // Check current authorization status
        checkLocationAuthorization()
    }
    
    private func updateDistanceFilter() {
        // Set distance filter based on granularity for efficient battery usage
        locationManager.distanceFilter = movementThreshold * 1000 // Convert km to meters
    }
    
    private func checkLocationAuthorization() {
        currentAuthorizationStatus = locationManager.authorizationStatus
        
        print("📍 Location authorization status: \(currentAuthorizationStatus.rawValue)")
        
        switch currentAuthorizationStatus {
        case .notDetermined:
            print("📍 Location not determined")
            isLocationEnabled = false
        case .restricted, .denied:
            print("📍 Location restricted or denied")
            isLocationEnabled = false
            locationManager.stopUpdatingLocation()
        case .authorizedWhenInUse:
            print("📍 Location authorized when in use - starting updates")
            isLocationEnabled = true
            locationManager.startUpdatingLocation()
            // Start monitoring significant location changes for background
            locationManager.startMonitoringSignificantLocationChanges()
        case .authorizedAlways:
            print("📍 Location authorized always - starting updates")
            isLocationEnabled = true
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            setupBackgroundLocationUpdates()
        @unknown default:
            isLocationEnabled = false
        }
    }
    
    // MARK: - Permission Requests
    
    func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        locationPermissionCompletion = completion
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            completion(true)
        default:
            completion(false)
        }
    }
    
    func requestAlwaysAuthorization(completion: @escaping (Bool) -> Void) {
        alwaysAuthorizationCompletion = completion
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            completion(true)
        default:
            completion(false)
        }
    }
    
    // MARK: - Background Location
    
    private func setupBackgroundLocationUpdates() {
        // Configure for background updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Start monitoring significant location changes
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Set up region monitoring for current location
        if let location = actualLocation {
            setupGeofencing(around: location.coordinate)
        }
    }
    
    private func setupGeofencing(around coordinate: CLLocationCoordinate2D) {
        // Stop monitoring previous regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        // Create a new region based on movement threshold
        let region = CLCircularRegion(
            center: coordinate,
            radius: movementThreshold * 1000, // Convert km to meters
            identifier: "MovementDetection"
        )
        region.notifyOnExit = true
        region.notifyOnEntry = false
        
        locationManager.startMonitoring(for: region)
    }
    
    // MARK: - Known Location Management
    
    func updateKnownLocation(coordinate: CLLocationCoordinate2D, name: String) {
        knownLocation = coordinate
        knownLocationName = name
        lastKnownLocationUpdate = Date()
        showTravelSuggestion = false
        lastSuggestionLocation = actualLocation
        
        // Update geofencing for new location
        setupGeofencing(around: coordinate)
        
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
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        UserDefaults.standard.set(locationDict, forKey: knownLocationKey)
        UserDefaults.standard.set(knownLocationName, forKey: knownLocationNameKey)
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
    }
    
    private func loadStoredKnownLocation() {
        // TEMPORARILY DISABLED - Don't load any cached location to force fresh detection
        // This ensures we always get the actual current location
        print("📍 Skipping cached location load - forcing fresh location detection")
        return
        
        /* Disabled for debugging
        // Don't load cached location if it's too old (more than 24 hours)
        if let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date {
            let hoursSinceUpdate = Date().timeIntervalSince(lastUpdate) / 3600
            if hoursSinceUpdate > 24 {
                // Clear outdated location cache
                clearStoredKnownLocation()
                return
            }
        }
        
        if let locationDict = UserDefaults.standard.dictionary(forKey: knownLocationKey),
           let latitude = locationDict["latitude"] as? Double,
           let longitude = locationDict["longitude"] as? Double {
            knownLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        knownLocationName = UserDefaults.standard.string(forKey: knownLocationNameKey) ?? ""
        lastKnownLocationUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
        */
    }
    
    func clearStoredKnownLocation() {
        UserDefaults.standard.removeObject(forKey: knownLocationKey)
        UserDefaults.standard.removeObject(forKey: knownLocationNameKey)
        UserDefaults.standard.removeObject(forKey: lastUpdateKey)
        knownLocation = nil
        knownLocationName = ""
        lastKnownLocationUpdate = nil
    }
    
    // Force refresh current location
    func refreshCurrentLocation() {
        // Clear any cached location
        clearStoredKnownLocation()
        
        // Request fresh location
        if isLocationEnabled {
            locationManager.requestLocation()
        }
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
    
    
    // MARK: - Database Sync
    
    private func syncKnownLocationToDatabase() async {
        guard let location = knownLocation else { return }
        
        do {
            let session = try await SupabaseManager.shared.auth.session
            
            struct LocationUpdate: Codable {
                let known_location: LocationData
                let known_location_name: String
                let location_updated_at: String
                let updated_at: String
            }
            
            let locationData = LocationData(
                latitude: location.latitude,
                longitude: location.longitude,
                address: knownLocationName,
                city: nil,
                country: nil
            )
            
            let update = LocationUpdate(
                known_location: locationData,
                known_location_name: knownLocationName,
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
            
            // Return full address for location
            if let thoroughfare = placemark.thoroughfare {
                components.append(thoroughfare)
            }
            if let locality = placemark.locality {
                components.append(locality)
            }
            if let country = placemark.country {
                components.append(country)
            }
            
            let locationName = components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
            completion(locationName)
        }
    }
    
    // Extract area code from location
    func extractAreaCode(from location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            completion(placemark.postalCode)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationPrivacyManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update actual location (kept private, never sent to server)
        actualLocation = location
        
        print("📍 Location update received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // If this is the first location update and we don't have a known location, set it
        if knownLocation == nil {
            print("📍 Setting initial known location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Get location name
            reverseGeocode(location: location) { [weak self] locationName in
                guard let self = self else { return }
                print("📍 Location name: \(locationName)")
                DispatchQueue.main.async {
                    self.updateKnownLocation(coordinate: location.coordinate, name: locationName)
                }
            }
        }
        
        // Check for significant travel
        checkForTravel()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let previousStatus = currentAuthorizationStatus
        checkLocationAuthorization()
        
        // Configure background location updates based on authorization
        if currentAuthorizationStatus == .authorizedAlways {
            // Only enable background updates with Always authorization
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.showsBackgroundLocationIndicator = true
        } else {
            // Disable background updates for other authorization states
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.pausesLocationUpdatesAutomatically = true
        }
        
        // Handle permission callbacks
        if previousStatus == .notDetermined {
            if currentAuthorizationStatus == .authorizedWhenInUse || currentAuthorizationStatus == .authorizedAlways {
                locationPermissionCompletion?(true)
            } else if currentAuthorizationStatus == .denied || currentAuthorizationStatus == .restricted {
                locationPermissionCompletion?(false)
            }
            locationPermissionCompletion = nil
        }
        
        // Handle always authorization callbacks
        if previousStatus == .authorizedWhenInUse && currentAuthorizationStatus == .authorizedAlways {
            alwaysAuthorizationCompletion?(true)
            alwaysAuthorizationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
    
    // MARK: - Region Monitoring
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "MovementDetection" else { return }
        
        // User has moved outside their geofence
        if let location = actualLocation {
            // Get location name for the new place
            reverseGeocode(location: location) { [weak self] locationName in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Show travel suggestion
                    self.showTravelSuggestion = true
                    self.travelDistance = self.movementThreshold
                    
                    // Send local notification if in background
                    if UIApplication.shared.applicationState == .background {
                        self.sendMovementNotification(locationName: locationName)
                    }
                }
            }
            
            // Set up new geofence at current location
            setupGeofencing(around: location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Region monitoring failed: \(error)")
    }
    
    // MARK: - Notifications
    
    private func sendMovementNotification(locationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Location Detected"
        content.body = "You've moved to \(locationName). Would you like to add a waypoint?"
        content.sound = .default
        content.categoryIdentifier = "MOVEMENT_DETECTION"
        
        // Add actions
        let addAction = UNNotificationAction(
            identifier: "ADD_WAYPOINT",
            title: "Add Waypoint",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "MOVEMENT_DETECTION",
            actions: [addAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}