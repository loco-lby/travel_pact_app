import Foundation
import Photos
import CoreLocation
import SwiftUI

// MARK: - Data Models

struct PhotoWaypoint {
    let id: UUID = UUID()
    let location: CLLocationCoordinate2D
    let locationName: String
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    let mediaAssets: [PHAsset]
    let granularityLevel: String
}

struct PhotoAnalysisProgress {
    let current: Int
    let total: Int
    let currentLocation: String?
    let message: String
}

// MARK: - Photo Analysis Service

class PhotoAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var progress: PhotoAnalysisProgress?
    @Published var errorMessage: String?
    @Published var excludedPhotosCount = 0
    @Published var waypoints: [PhotoWaypoint] = []
    
    private let geocoder = CLGeocoder()
    private var cancellationRequested = false
    
    // MARK: - Public Methods
    
    func analyzePhotoLibrary(granularity: String = "city") async throws {
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
            excludedPhotosCount = 0
            waypoints = []
            cancellationRequested = false
        }
        
        do {
            // Request photo library access
            let authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard authStatus == .authorized else {
                throw PhotoAnalysisError.unauthorized
            }
            
            // Fetch all photos with location data
            let photos = try await fetchPhotosWithLocation()
            
            if photos.isEmpty {
                throw PhotoAnalysisError.noPhotosWithLocation
            }
            
            // Process photos sequentially
            let processedWaypoints = try await processPhotosSequentially(
                photos: photos,
                granularity: granularity
            )
            
            print("📊 Processed \(processedWaypoints.count) waypoints from \(photos.count) photos")
            
            await MainActor.run {
                self.waypoints = processedWaypoints
                self.isAnalyzing = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isAnalyzing = false
            }
            throw error
        }
    }
    
    func cancelAnalysis() {
        cancellationRequested = true
    }
    
    // MARK: - Database Sync
    
    func syncToDatabase() async throws {
        guard !waypoints.isEmpty else {
            print("❌ No waypoints to sync")
            throw PhotoAnalysisError.noWaypointsToSync
        }
        
        print("📤 Starting sync of \(waypoints.count) waypoints to database")
        
        let session = try await SupabaseManager.shared.auth.session
        let userId = session.user.id
        
        // Create route
        print("📤 Creating route for user \(userId)")
        let routeId = try await createRoute(userId: userId)
        print("✅ Route created with ID: \(routeId)")
        
        // Create waypoints with media
        for (index, waypoint) in waypoints.enumerated() {
            if cancellationRequested { 
                print("⚠️ Sync cancelled by user")
                break 
            }
            
            print("📤 Creating waypoint \(index + 1)/\(waypoints.count): \(waypoint.locationName)")
            
            try await createWaypointWithMedia(
                waypoint: waypoint,
                routeId: routeId,
                userId: userId,
                sequenceOrder: index + 1
            )
            
            print("✅ Waypoint \(index + 1) created successfully")
            
            await MainActor.run {
                self.progress = PhotoAnalysisProgress(
                    current: index + 1,
                    total: waypoints.count,
                    currentLocation: waypoint.locationName,
                    message: "Syncing waypoints to database..."
                )
            }
        }
        
        print("✅ Successfully synced all waypoints to database")
    }
    
    // MARK: - Private Methods
    
    private func fetchPhotosWithLocation() async throws -> [PHAsset] {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            // Don't use predicate - filter manually for location
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var photos: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                // Only include photos that have location data
                if asset.location != nil {
                    photos.append(asset)
                }
            }
            
            continuation.resume(returning: photos)
        }
    }
    
    private func processPhotosSequentially(
        photos: [PHAsset],
        granularity: String
    ) async throws -> [PhotoWaypoint] {
        var waypoints: [PhotoWaypoint] = []
        var currentCluster: [PHAsset] = []
        var currentLocationKey: String?
        
        for (index, photo) in photos.enumerated() {
            if cancellationRequested { break }
            
            // Update progress
            await MainActor.run {
                self.progress = PhotoAnalysisProgress(
                    current: index + 1,
                    total: photos.count,
                    currentLocation: nil,
                    message: "Analyzing photo \(index + 1) of \(photos.count)..."
                )
            }
            
            guard let location = photo.location else {
                await MainActor.run {
                    self.excludedPhotosCount += 1
                }
                continue
            }
            
            // Get location key based on granularity
            let locationKey = try await getLocationKey(
                for: location.coordinate,
                granularity: granularity
            )
            
            // Check if this is a new location
            if currentLocationKey == nil || currentLocationKey != locationKey {
                // Save previous cluster if exists
                if !currentCluster.isEmpty, let prevKey = currentLocationKey {
                    let waypoint = try await createWaypoint(
                        from: currentCluster,
                        locationKey: prevKey,
                        granularity: granularity
                    )
                    waypoints.append(waypoint)
                }
                
                // Start new cluster
                currentLocationKey = locationKey
                currentCluster = [photo]
            } else {
                // Add to current cluster
                currentCluster.append(photo)
            }
        }
        
        // Don't forget the last cluster
        if !currentCluster.isEmpty, let lastKey = currentLocationKey {
            let waypoint = try await createWaypoint(
                from: currentCluster,
                locationKey: lastKey,
                granularity: granularity
            )
            waypoints.append(waypoint)
        }
        
        return waypoints
    }
    
    private func getLocationKey(
        for coordinate: CLLocationCoordinate2D,
        granularity: String
    ) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        guard let placemark = try await geocoder.reverseGeocodeLocation(location).first else {
            return "Unknown Location"
        }
        
        switch granularity {
        case "city":
            return placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "Unknown"
        case "region":
            return placemark.administrativeArea ?? placemark.country ?? "Unknown"
        case "country":
            return placemark.country ?? "Unknown"
        default:
            return placemark.locality ?? "Unknown"
        }
    }
    
    private func createWaypoint(
        from assets: [PHAsset],
        locationKey: String,
        granularity: String
    ) async throws -> PhotoWaypoint {
        guard let firstAsset = assets.first,
              let lastAsset = assets.last,
              let firstLocation = firstAsset.location else {
            throw PhotoAnalysisError.invalidAssetData
        }
        
        // Get detailed location name
        let locationName = try await getDetailedLocationName(
            for: firstLocation.coordinate,
            locationKey: locationKey
        )
        
        // Format dates
        let startDate = firstAsset.creationDate ?? Date()
        let endDate = lastAsset.creationDate ?? Date()
        
        return PhotoWaypoint(
            location: firstLocation.coordinate,
            locationName: formatWaypointName(locationName, startDate: startDate, endDate: endDate),
            startDate: startDate,
            endDate: endDate,
            photoCount: assets.count,
            mediaAssets: assets,
            granularityLevel: granularity
        )
    }
    
    private func getDetailedLocationName(
        for coordinate: CLLocationCoordinate2D,
        locationKey: String
    ) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        guard let placemark = try await geocoder.reverseGeocodeLocation(location).first else {
            return locationKey
        }
        
        // Return city name if available, otherwise use the key
        return placemark.locality ?? locationKey
    }
    
    private func formatWaypointName(
        _ location: String,
        startDate: Date,
        endDate: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startStr = formatter.string(from: startDate)
        
        // Check if same day
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return "\(location) (\(startStr))"
        }
        
        let endStr = formatter.string(from: endDate)
        
        // Check if same year
        if Calendar.current.component(.year, from: startDate) == Calendar.current.component(.year, from: endDate) {
            return "\(location) (\(startStr) - \(endStr))"
        }
        
        // Different years
        formatter.dateFormat = "MMM d, yyyy"
        let startFullStr = formatter.string(from: startDate)
        let endFullStr = formatter.string(from: endDate)
        return "\(location) (\(startFullStr) - \(endFullStr))"
    }
    
    // MARK: - Database Operations
    
    private func createRoute(userId: UUID) async throws -> UUID {
        struct RouteInsert: Codable {
            let user_id: String
            let name: String
            let description: String?
            let status: String
            let privacy_level: String
            let start_date: String
            let created_at: String
            let updated_at: String
        }
        
        let route = RouteInsert(
            user_id: userId.uuidString,
            name: "My Travel Timeline",
            description: "Automatically generated from photo library",
            status: "completed",
            privacy_level: "private",
            start_date: ISO8601DateFormatter().string(from: waypoints.first?.startDate ?? Date()),
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await SupabaseManager.shared.client
            .from("routes")
            .insert(route)
            .select("id")
            .execute()
        
        print("📊 Route insert response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
        
        let dataArray = try JSONDecoder().decode([[String: String]].self, from: response.data)
        guard let data = dataArray.first,
              let idString = data["id"],
              let routeId = UUID(uuidString: idString) else {
            print("❌ Failed to parse route ID from response")
            throw PhotoAnalysisError.databaseError
        }
        
        return routeId
    }
    
    private func createWaypointWithMedia(
        waypoint: PhotoWaypoint,
        routeId: UUID,
        userId: UUID,
        sequenceOrder: Int
    ) async throws {
        // Create waypoint
        struct WaypointInsert: Codable {
            let route_id: String
            let user_id: String
            let name: String
            let known_location: LocationData
            let granularity_level: String
            let sequence_order: Int
            let arrival_time: String  // Changed from arrival_date to arrival_time
            let departure_time: String  // Changed from departure_date to departure_time
            let created_at: String
            let updated_at: String
        }
        
        let locationData = LocationData(
            latitude: waypoint.location.latitude,
            longitude: waypoint.location.longitude,
            address: waypoint.locationName,
            city: nil,
            country: nil
        )
        
        let waypointInsert = WaypointInsert(
            route_id: routeId.uuidString,
            user_id: userId.uuidString,
            name: waypoint.locationName,
            known_location: locationData,
            granularity_level: waypoint.granularityLevel,
            sequence_order: sequenceOrder,
            arrival_time: ISO8601DateFormatter().string(from: waypoint.startDate),  // Changed to arrival_time
            departure_time: ISO8601DateFormatter().string(from: waypoint.endDate),  // Changed to departure_time
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let waypointResponse = try await SupabaseManager.shared.client
            .from("waypoints")
            .insert(waypointInsert)
            .select("id")
            .execute()
        
        let waypointDataArray = try JSONDecoder().decode([[String: String]].self, from: waypointResponse.data)
        guard let waypointData = waypointDataArray.first,
              let waypointIdString = waypointData["id"],
              let waypointId = UUID(uuidString: waypointIdString) else {
            throw PhotoAnalysisError.databaseError
        }
        
        // Create media entries for photos
        struct MediaInsert: Codable {
            let waypoint_id: String
            let user_id: String
            let file_path: String  // Changed from asset_identifier to file_path (required field)
            let media_type: String
            let caption: String?
            let privacy_level: String
            let created_at: String
            let updated_at: String
        }
        
        var mediaInserts: [MediaInsert] = []
        for asset in waypoint.mediaAssets {
            // Store the asset identifier as the file_path for now
            // This will be used to reference the photo library asset
            let media = MediaInsert(
                waypoint_id: waypointId.uuidString,
                user_id: userId.uuidString,
                file_path: "photolib://\(asset.localIdentifier)",  // Using a custom scheme to indicate photo library reference
                media_type: "photo",
                caption: nil,
                privacy_level: "private",
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            mediaInserts.append(media)
        }
        
        if !mediaInserts.isEmpty {
            _ = try await SupabaseManager.shared.client
                .from("media")
                .insert(mediaInserts)
                .execute()
        }
    }
}

// MARK: - Error Types

enum PhotoAnalysisError: LocalizedError {
    case unauthorized
    case noPhotosWithLocation
    case noWaypointsToSync
    case invalidAssetData
    case databaseError
    case geocodingFailed
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Photo library access denied. Please grant permission in Settings."
        case .noPhotosWithLocation:
            return "No photos with location data found in your library."
        case .noWaypointsToSync:
            return "No waypoints to sync to database."
        case .invalidAssetData:
            return "Invalid photo data encountered."
        case .databaseError:
            return "Failed to sync with database."
        case .geocodingFailed:
            return "Failed to determine location names."
        }
    }
}