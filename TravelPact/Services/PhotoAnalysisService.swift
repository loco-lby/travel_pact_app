// MVP: Media features temporarily disabled for contact location focus
/*
import Foundation
import Photos
import CoreLocation
import SwiftUI

// MARK: - Data Models

struct PhotoWaypoint: Identifiable, Codable {
    let id: UUID
    let location: CLLocationCoordinate2D
    let locationName: String
    let areaCode: String?  // Postal/ZIP code
    let city: String?
    let country: String?
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    let granularityLevel: String
    
    // PHAsset cannot be encoded, so we make it transient
    var mediaAssets: [PHAsset] = []
    
    init(id: UUID = UUID(),
         location: CLLocationCoordinate2D,
         locationName: String,
         areaCode: String?,
         city: String?,
         country: String?,
         startDate: Date,
         endDate: Date,
         photoCount: Int,
         mediaAssets: [PHAsset],
         granularityLevel: String) {
        self.id = id
        self.location = location
        self.locationName = locationName
        self.areaCode = areaCode
        self.city = city
        self.country = country
        self.startDate = startDate
        self.endDate = endDate
        self.photoCount = photoCount
        self.mediaAssets = mediaAssets
        self.granularityLevel = granularityLevel
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, locationName, areaCode, city, country
        case startDate, endDate, photoCount, granularityLevel
        case latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        locationName = try container.decode(String.self, forKey: .locationName)
        areaCode = try container.decodeIfPresent(String.self, forKey: .areaCode)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        photoCount = try container.decode(Int.self, forKey: .photoCount)
        granularityLevel = try container.decode(String.self, forKey: .granularityLevel)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        mediaAssets = [] // Will be empty when decoded
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(locationName, forKey: .locationName)
        try container.encodeIfPresent(areaCode, forKey: .areaCode)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(photoCount, forKey: .photoCount)
        try container.encode(granularityLevel, forKey: .granularityLevel)
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
    }
}

struct PhotoAnalysisProgress {
    let current: Int
    let total: Int
    let currentLocation: String?
    let message: String
    let waypointsFound: Int
    let photosSkipped: Int
}

// MARK: - Geocoding Cache

class GeocodingCache {
    private var cache: [String: CLPlacemark] = [:]
    private let cacheQueue = DispatchQueue(label: "com.travelpact.geocoding.cache", attributes: .concurrent)
    
    func key(for coordinate: CLLocationCoordinate2D) -> String {
        // Round to 3 decimal places (about 100m precision) for cache efficiency
        let lat = round(coordinate.latitude * 1000) / 1000
        let lon = round(coordinate.longitude * 1000) / 1000
        return "\(lat),\(lon)"
    }
    
    func get(_ coordinate: CLLocationCoordinate2D) -> CLPlacemark? {
        cacheQueue.sync {
            cache[key(for: coordinate)]
        }
    }
    
    func set(_ placemark: CLPlacemark, for coordinate: CLLocationCoordinate2D) {
        cacheQueue.async(flags: .barrier) {
            self.cache[self.key(for: coordinate)] = placemark
        }
    }
    
    func clear() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - Photo Analysis Service

class PhotoAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var progress: PhotoAnalysisProgress?
    @Published var errorMessage: String?
    @Published var excludedPhotosCount = 0
    @Published var waypoints: [PhotoWaypoint] = []
    @Published var isPaused = false
    
    private let geocoder = CLGeocoder()
    private let geocodingCache = GeocodingCache()
    private var cancellationRequested = false
    private var pauseRequested = false
    
    // Rate limiting configuration
    private let geocodingDelay: TimeInterval = 0.2 // 200ms between requests (5 requests per second max)
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    private let batchSize = 100 // Process photos in batches
    
    // Progress persistence
    private var lastProcessedIndex: Int = 0
    private let progressKey = "PhotoAnalysisLastProcessedIndex"
    
    // MARK: - Public Methods
    
    func analyzePhotoLibrary(granularity: String = "city", resumeFromLastPosition: Bool = false, selectedAssets: [PHAsset]? = nil) async throws {
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
            if !resumeFromLastPosition {
                excludedPhotosCount = 0
                waypoints = []
                lastProcessedIndex = 0
            }
            cancellationRequested = false
            pauseRequested = false
            isPaused = false
        }
        
        do {
            // Request photo library access
            let authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard authStatus == .authorized else {
                throw PhotoAnalysisError.unauthorized
            }
            
            // Use selected assets or fetch all photos with location data
            let photos = if let selected = selectedAssets {
                selected.filter { $0.location != nil }
            } else {
                try await fetchPhotosWithLocation()
            }
            
            if photos.isEmpty {
                throw PhotoAnalysisError.noPhotosWithLocation
            }
            
            // Determine starting point
            let startIndex = resumeFromLastPosition ? UserDefaults.standard.integer(forKey: progressKey) : 0
            
            print("📊 Starting analysis of \(photos.count) photos from index \(startIndex)")
            
            // Process photos in batches with rate limiting
            let processedWaypoints = try await processPhotosInBatches(
                photos: photos,
                granularity: granularity,
                startIndex: startIndex
            )
            
            print("📊 Successfully processed \(processedWaypoints.count) waypoints from \(photos.count) photos")
            
            await MainActor.run {
                self.waypoints = processedWaypoints
                self.isAnalyzing = false
                // Clear progress on successful completion
                UserDefaults.standard.removeObject(forKey: self.progressKey)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isAnalyzing = false
            }
            throw error
        }
    }
    
    func pauseAnalysis() {
        pauseRequested = true
        isPaused = true
    }
    
    func resumeAnalysis() async throws {
        pauseRequested = false
        isPaused = false
        try await analyzePhotoLibrary(resumeFromLastPosition: true)
    }
    
    func cancelAnalysis() {
        cancellationRequested = true
        // Clear saved progress
        UserDefaults.standard.removeObject(forKey: progressKey)
    }
    
    // MARK: - Database Sync
    
    func syncToDatabase(selectedWaypointIds: Set<UUID>? = nil) async throws {
        // Filter waypoints based on selection
        let waypointsToSync = if let selectedIds = selectedWaypointIds {
            waypoints.filter { selectedIds.contains($0.id) }
        } else {
            waypoints
        }
        
        guard !waypointsToSync.isEmpty else {
            print("❌ No waypoints to sync")
            throw PhotoAnalysisError.noWaypointsToSync
        }
        
        print("📤 Starting sync of \(waypointsToSync.count) waypoints to database (out of \(waypoints.count) total)")
        
        let session = try await SupabaseManager.shared.auth.session
        let userId = session.user.id
        
        // Create route
        print("📤 Creating route for user \(userId)")
        let routeId = try await createRoute(userId: userId, waypoints: waypointsToSync)
        print("✅ Route created with ID: \(routeId)")
        
        // Create waypoints with media
        for (index, waypoint) in waypointsToSync.enumerated() {
            if cancellationRequested { 
                print("⚠️ Sync cancelled by user")
                break 
            }
            
            print("📤 Creating waypoint \(index + 1)/\(waypointsToSync.count): \(waypoint.locationName)")
            
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
                    total: waypointsToSync.count,
                    currentLocation: waypoint.locationName,
                    message: "Syncing waypoints to database...",
                    waypointsFound: waypointsToSync.count,
                    photosSkipped: 0
                )
            }
        }
        
        print("✅ Successfully synced all waypoints to database")
    }
    
    // MARK: - Private Methods
    
    func fetchAllPhotos() async -> [PHAsset] {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var photos: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                photos.append(asset)
            }
            
            continuation.resume(returning: photos)
        }
    }
    
    private func fetchPhotosWithLocation() async throws -> [PHAsset] {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
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
    
    private func processPhotosInBatches(
        photos: [PHAsset],
        granularity: String,
        startIndex: Int
    ) async throws -> [PhotoWaypoint] {
        var allWaypoints: [PhotoWaypoint] = []
        var locationClusters: [String: [PHAsset]] = [:]
        var photosProcessed = startIndex
        var photosSkipped = 0
        var geocodingErrors = 0
        
        // Process in batches to manage memory and allow for progress updates
        for batchStart in stride(from: startIndex, to: photos.count, by: batchSize) {
            if cancellationRequested || pauseRequested { 
                // Save progress
                UserDefaults.standard.set(photosProcessed, forKey: progressKey)
                break 
            }
            
            let batchEnd = min(batchStart + batchSize, photos.count)
            let batch = Array(photos[batchStart..<batchEnd])
            
            print("📦 Processing batch: photos \(batchStart) to \(batchEnd)")
            
            for photo in batch {
                photosProcessed += 1
                
                // Update progress
                await MainActor.run {
                    self.progress = PhotoAnalysisProgress(
                        current: photosProcessed,
                        total: photos.count,
                        currentLocation: nil,
                        message: "Analyzing photo \(photosProcessed) of \(photos.count)...",
                        waypointsFound: allWaypoints.count,
                        photosSkipped: photosSkipped
                    )
                }
                
                guard let location = photo.location else {
                    photosSkipped += 1
                    await MainActor.run {
                        self.excludedPhotosCount += 1
                    }
                    continue
                }
                
                // Try to get location key with caching and rate limiting
                do {
                    let locationKey = try await getLocationKeyWithCache(
                        for: location.coordinate,
                        granularity: granularity
                    )
                    
                    // Cluster photos by location
                    if locationClusters[locationKey] != nil {
                        locationClusters[locationKey]?.append(photo)
                    } else {
                        locationClusters[locationKey] = [photo]
                    }
                    
                    // Reset error counter on success
                    geocodingErrors = 0
                    
                } catch {
                    print("⚠️ Geocoding error for photo \(photosProcessed): \(error)")
                    geocodingErrors += 1
                    photosSkipped += 1
                    
                    // If we get too many consecutive errors, pause briefly
                    if geocodingErrors > 5 {
                        print("⏸ Too many geocoding errors, pausing for 5 seconds...")
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                        geocodingErrors = 0
                    }
                }
            }
            
            // Save progress after each batch
            UserDefaults.standard.set(photosProcessed, forKey: progressKey)
        }
        
        // Convert clusters to waypoints
        print("📍 Creating waypoints from \(locationClusters.count) location clusters")
        
        for (locationKey, assets) in locationClusters {
            if cancellationRequested { break }
            
            do {
                let waypoint = try await createWaypointFromCluster(
                    assets: assets,
                    locationKey: locationKey,
                    granularity: granularity
                )
                allWaypoints.append(waypoint)
            } catch {
                print("⚠️ Failed to create waypoint for \(locationKey): \(error)")
                // Continue processing other waypoints
            }
        }
        
        // Sort waypoints by date
        allWaypoints.sort { $0.startDate < $1.startDate }
        
        // Clear progress on successful completion
        if photosProcessed >= photos.count {
            UserDefaults.standard.removeObject(forKey: progressKey)
        }
        
        return allWaypoints
    }
    
    private func getLocationKeyWithCache(
        for coordinate: CLLocationCoordinate2D,
        granularity: String
    ) async throws -> String {
        // Check cache first
        if let cachedPlacemark = geocodingCache.get(coordinate) {
            return extractLocationKey(from: cachedPlacemark, granularity: granularity)
        }
        
        // Rate limiting delay
        try await Task.sleep(nanoseconds: UInt64(geocodingDelay * 1_000_000_000))
        
        // Perform geocoding with retry logic
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                
                if let placemark = placemarks.first {
                    // Cache the result
                    geocodingCache.set(placemark, for: coordinate)
                    return extractLocationKey(from: placemark, granularity: granularity)
                }
                
                return "Unknown Location"
                
            } catch let error as NSError where error.domain == kCLErrorDomain && error.code == 2 {
                // Rate limit error - wait longer before retry
                lastError = error
                print("⚠️ Geocoding rate limit hit, attempt \(attempt)/\(maxRetries)")
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
            } catch {
                // Other errors
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        // If all retries failed, return a coordinate-based key
        print("⚠️ All geocoding attempts failed, using coordinate-based key")
        return "\(round(coordinate.latitude * 100) / 100),\(round(coordinate.longitude * 100) / 100)"
    }
    
    private func extractLocationKey(from placemark: CLPlacemark, granularity: String) -> String {
        switch granularity {
        case "precise":
            // Use exact coordinates as key
            if let location = placemark.location {
                return "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            }
            return "Unknown"
        case "area_code":
            // Use postal code as primary key
            return placemark.postalCode ?? placemark.locality ?? placemark.country ?? "Unknown"
        case "city":
            return placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? "Unknown"
        case "country":
            return placemark.country ?? "Unknown"
        default:
            return placemark.locality ?? "Unknown"
        }
    }
    
    private func createWaypointFromCluster(
        assets: [PHAsset],
        locationKey: String,
        granularity: String
    ) async throws -> PhotoWaypoint {
        guard let firstAsset = assets.first,
              let lastAsset = assets.last,
              let firstLocation = firstAsset.location else {
            throw PhotoAnalysisError.invalidAssetData
        }
        
        // Sort assets by date to get proper date range
        let sortedAssets = assets.sorted { 
            ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) 
        }
        
        let startDate = sortedAssets.first?.creationDate ?? Date()
        let endDate = sortedAssets.last?.creationDate ?? Date()
        
        // Try to get detailed location info from cache or with rate limiting
        var placemark: CLPlacemark?
        if let cached = geocodingCache.get(firstLocation.coordinate) {
            placemark = cached
        } else {
            // Try geocoding with rate limit protection
            do {
                try await Task.sleep(nanoseconds: UInt64(geocodingDelay * 1_000_000_000))
                let location = CLLocation(
                    latitude: firstLocation.coordinate.latitude,
                    longitude: firstLocation.coordinate.longitude
                )
                placemark = try await geocoder.reverseGeocodeLocation(location).first
                if let placemark = placemark {
                    geocodingCache.set(placemark, for: firstLocation.coordinate)
                }
            } catch {
                print("⚠️ Failed to get detailed location for waypoint: \(error)")
            }
        }
        
        // Extract location components
        let areaCode = placemark?.postalCode
        let city = placemark?.locality ?? locationKey
        let country = placemark?.country
        
        // Format location name
        let locationName = formatWaypointName(city, startDate: startDate, endDate: endDate)
        
        return PhotoWaypoint(
            id: UUID(),
            location: firstLocation.coordinate,
            locationName: locationName,
            areaCode: areaCode,
            city: city,
            country: country,
            startDate: startDate,
            endDate: endDate,
            photoCount: assets.count,
            mediaAssets: sortedAssets,
            granularityLevel: granularity
        )
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
    
    private func createRoute(userId: UUID, waypoints waypointsToSync: [PhotoWaypoint]) async throws -> UUID {
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
            start_date: ISO8601DateFormatter().string(from: waypointsToSync.first?.startDate ?? Date()),
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
    
    private func fetchImageData(from asset: PHAsset) async -> Data? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { imageData, _, _, _ in
                continuation.resume(returning: imageData)
            }
        }
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
            let arrival_time: String
            let departure_time: String
            let area_code: String?
            let city: String?
            let country: String?
            let created_at: String
            let updated_at: String
        }
        
        let locationData = LocationData(
            latitude: waypoint.location.latitude,
            longitude: waypoint.location.longitude,
            address: waypoint.locationName,
            city: waypoint.city,
            country: waypoint.country
        )
        
        let waypointInsert = WaypointInsert(
            route_id: routeId.uuidString,
            user_id: userId.uuidString,
            name: waypoint.locationName,
            known_location: locationData,
            granularity_level: waypoint.granularityLevel,
            sequence_order: sequenceOrder,
            arrival_time: ISO8601DateFormatter().string(from: waypoint.startDate),
            departure_time: ISO8601DateFormatter().string(from: waypoint.endDate),
            area_code: waypoint.areaCode,
            city: waypoint.city,
            country: waypoint.country,
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
        
        // Upload photos and create media entries (limit to avoid overwhelming storage)
        let uploadService = MediaUploadService.shared
        let photosToUpload = Array(waypoint.mediaAssets.prefix(5)) // Reduced from 10 to 5
        
        for asset in photosToUpload {
            // Fetch image data from PHAsset
            let imageData = await fetchImageData(from: asset)
            
            if let imageData = imageData {
                // Create waypoint object for upload
                let waypointObj = Waypoint(
                    id: waypointId,
                    routeId: routeId,
                    userId: userId,
                    name: waypoint.locationName,
                    knownLocation: locationData,
                    actualLocation: nil,
                    granularityLevel: waypoint.granularityLevel,
                    sequenceOrder: sequenceOrder,
                    arrivalTime: waypoint.startDate,
                    departureTime: waypoint.endDate,
                    city: waypoint.city,
                    areaCode: waypoint.areaCode,
                    country: waypoint.country,
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                // Upload photo with metadata
                let metadata = PhotoMetadata(
                    creationDate: asset.creationDate,
                    location: asset.location,
                    cameraInfo: nil
                )
                
                do {
                    _ = try await uploadService.uploadAnalyzedPhoto(
                        imageData: imageData,
                        waypoint: waypointObj,
                        metadata: metadata,
                        privacyLevel: "private"
                    )
                } catch {
                    print("⚠️ Failed to upload photo: \(error)")
                    // Continue with next photo even if one fails
                }
            }
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
*/