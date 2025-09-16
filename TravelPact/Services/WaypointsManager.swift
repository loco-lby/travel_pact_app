import Foundation
import CoreLocation
import Combine
import Supabase

struct Waypoint: Identifiable, Codable, Equatable {
    let id: UUID
    let routeId: UUID
    let userId: UUID
    let name: String
    let knownLocation: LocationData?
    let actualLocation: LocationData?
    let granularityLevel: String?
    let sequenceOrder: Int
    let arrivalTime: Date?  // Changed from arrivalDate to arrivalTime
    let departureTime: Date?  // Changed from departureDate to departureTime
    let city: String?
    let areaCode: String?  // Postal/ZIP code for precise location control
    let country: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Computed property for map display
    var coordinate: CLLocationCoordinate2D? {
        // Use known location first, fall back to actual location
        if let location = knownLocation {
            return CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
        } else if let location = actualLocation {
            return CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case routeId = "route_id"
        case userId = "user_id"
        case name
        case knownLocation = "known_location"
        case actualLocation = "actual_location"
        case granularityLevel = "granularity_level"
        case sequenceOrder = "sequence_order"
        case arrivalTime = "arrival_time"  // Changed from arrival_date
        case departureTime = "departure_time"  // Changed from departure_date
        case city
        case areaCode = "area_code"
        case country
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

class WaypointsManager: ObservableObject {
    @Published var waypoints: [Waypoint] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    func loadWaypoints() {
        Task { @MainActor in
            isLoading = true
            errorMessage = ""
            do {
                let session = try await SupabaseManager.shared.auth.session
                
                let response = try await SupabaseManager.shared.client
                    .from("waypoints")
                    .select()
                    .eq("user_id", value: session.user.id.uuidString)
                    .order("sequence_order", ascending: true)
                    .execute()
                
                let decoder = JSONDecoder()
                // Custom date decoding for PostgreSQL timestamps
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Create formatters
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    // Try formats in order of likelihood
                    let formats = [
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // "2025-09-08T01:19:02.374887+00:00"
                        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",         // "2025-09-08T01:19:02+00:00"
                        "yyyy-MM-dd HH:mm:ss.SSSSSSZ",        // "2025-09-08 01:19:02.374887+00"
                        "yyyy-MM-dd HH:mm:ssZ",               // "2025-09-08 00:56:16+00"
                        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",       // "2025-09-08T01:19:02.374Z"
                        "yyyy-MM-dd'T'HH:mm:ss'Z'"            // "2025-09-08T01:19:02Z"
                    ]
                    
                    for format in formats {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                    }
                    
                    // Try ISO8601 formatter as fallback
                    let iso8601Formatter = ISO8601DateFormatter()
                    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    
                    iso8601Formatter.formatOptions = [.withInternetDateTime]
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                let loadedWaypoints = try decoder.decode([Waypoint].self, from: response.data)
                
                self.waypoints = loadedWaypoints
                self.isLoading = false
                
                print("✅ Loaded \(loadedWaypoints.count) bookmarks")
            } catch {
                self.errorMessage = "Failed to load bookmarks: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Error loading bookmarks: \(error)")
            }
        }
    }
    
    func updateWaypoint(_ waypoint: Waypoint) {
        Task {
            do {
                struct WaypointUpdate: Codable {
                    let name: String
                    let notes: String?
                    let updated_at: String
                }
                
                let update = WaypointUpdate(
                    name: waypoint.name,
                    notes: waypoint.notes,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await SupabaseManager.shared.client
                    .from("waypoints")
                    .update(update)
                    .eq("id", value: waypoint.id.uuidString)
                    .execute()
                
                // Update local array
                if let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) {
                    await MainActor.run {
                        waypoints[index] = waypoint
                    }
                }
                
                print("✅ Updated bookmark: \(waypoint.name)")
            } catch {
                print("❌ Error updating bookmark: \(error)")
            }
        }
    }
    
    func deleteWaypoint(_ waypoint: Waypoint) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        // Delete the waypoint from database
        _ = try await SupabaseManager.shared.client
            .from("waypoints")
            .delete()
            .eq("id", value: waypoint.id.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        // Update sequence orders for remaining bookmarks in database
        await reorderWaypoints(afterDeletion: waypoint.sequenceOrder, routeId: waypoint.routeId)
        
        // Remove from local array immediately
        await MainActor.run {
            self.waypoints.removeAll { $0.id == waypoint.id }
            // Update local sequence orders
            for index in self.waypoints.indices {
                if self.waypoints[index].routeId == waypoint.routeId && self.waypoints[index].sequenceOrder > waypoint.sequenceOrder {
                    // Create new waypoint with updated sequence order
                    let wp = self.waypoints[index]
                    self.waypoints[index] = Waypoint(
                        id: wp.id,
                        routeId: wp.routeId,
                        userId: wp.userId,
                        name: wp.name,
                        knownLocation: wp.knownLocation,
                        actualLocation: wp.actualLocation,
                        granularityLevel: wp.granularityLevel,
                        sequenceOrder: wp.sequenceOrder - 1,
                        arrivalTime: wp.arrivalTime,
                        departureTime: wp.departureTime,
                        city: wp.city,
                        areaCode: wp.areaCode,
                        country: wp.country,
                        notes: wp.notes,
                        createdAt: wp.createdAt,
                        updatedAt: Date()
                    )
                }
            }
        }
        
        print("✅ Deleted bookmark: \(waypoint.name)")
        
        // Reload to sync with database
        await MainActor.run {
            loadWaypoints()
        }
    }
    
    func splitRouteAtWaypoint(_ waypoint: Waypoint) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        // Get bookmarks before and after the split point
        let waypointsBefore = waypoints.filter { 
            $0.routeId == waypoint.routeId && $0.sequenceOrder < waypoint.sequenceOrder 
        }
        
        let waypointsAfter = waypoints.filter { 
            $0.routeId == waypoint.routeId && $0.sequenceOrder > waypoint.sequenceOrder 
        }
        
        // Only split if there are bookmarks both before AND after this one
        // This creates two distinct paths
        if !waypointsBefore.isEmpty && !waypointsAfter.isEmpty {
            // Create a new route for waypoints after the split point
            struct RouteInsert: Codable {
                let user_id: String
                let name: String
                let description: String?
                let status: String
                let privacy_level: String
                let created_at: String
                let updated_at: String
            }
            
            // Get the original route name for better naming
            let originalRouteName = "Route"
            
            let newRoute = RouteInsert(
                user_id: session.user.id.uuidString,
                name: "\(originalRouteName) - Part 2",
                description: "Second part of route split at \(waypoint.name)",
                status: "completed",
                privacy_level: "private",
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            let routeResponse = try await SupabaseManager.shared.client
                .from("routes")
                .insert(newRoute)
                .select("id")
                .execute()
            
            let routeData = try JSONDecoder().decode([[String: String]].self, from: routeResponse.data)
            guard let newRouteId = routeData.first?["id"],
                  let newRouteUUID = UUID(uuidString: newRouteId) else {
                throw WaypointError.routeCreationFailed
            }
            
            // Update bookmarks after the split point to belong to the new route
            // Reset their sequence orders starting from 0
            for (index, wp) in waypointsAfter.enumerated() {
                struct WaypointRouteUpdate: Codable {
                    let route_id: String
                    let sequence_order: Int
                    let updated_at: String
                }
                
                let update = WaypointRouteUpdate(
                    route_id: newRouteUUID.uuidString,
                    sequence_order: index,
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await SupabaseManager.shared.client
                    .from("waypoints")
                    .update(update)
                    .eq("id", value: wp.id.uuidString)
                    .execute()
            }
            
            print("✅ Split route at bookmark: \(waypoint.name)")
            print("   - Original route now has \(waypointsBefore.count) bookmarks")
            print("   - New route has \(waypointsAfter.count) bookmarks")
        } else if waypointsAfter.isEmpty {
            // If no bookmarks after, just delete the last bookmark
            print("⚠️ No bookmarks after \(waypoint.name), just deleting it")
        } else if waypointsBefore.isEmpty {
            // If no bookmarks before, just delete the first bookmark
            print("⚠️ No bookmarks before \(waypoint.name), just deleting it")
        }
        
        // Delete the bookmark at the split point
        // This separates the two paths completely
        try await deleteWaypoint(waypoint)
    }
    
    private func reorderWaypoints(afterDeletion deletedOrder: Int, routeId: UUID) async {
        // Update sequence orders for bookmarks after the deleted one
        let waypointsToUpdate = waypoints.filter { 
            $0.routeId == routeId && $0.sequenceOrder > deletedOrder 
        }
        
        for waypoint in waypointsToUpdate {
            struct SequenceUpdate: Codable {
                let sequence_order: Int
                let updated_at: String
            }
            
            let update = SequenceUpdate(
                sequence_order: waypoint.sequenceOrder - 1,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            do {
                _ = try await SupabaseManager.shared.client
                    .from("waypoints")
                    .update(update)
                    .eq("id", value: waypoint.id.uuidString)
                    .execute()
            } catch {
                print("❌ Error reordering bookmark: \(error)")
            }
        }
    }
    
    func createWaypoint(name: String, location: CLLocationCoordinate2D) async throws -> Waypoint {
        let session = try await SupabaseManager.shared.auth.session
        
        // Get user's main route or create one if it doesn't exist
        let routeId = try await getOrCreateMainRoute(for: session.user.id)
        
        // Determine the sequence order for the new bookmark
        let maxSequence = waypoints
            .filter { $0.routeId == routeId }
            .map { $0.sequenceOrder }
            .max() ?? -1
        let newSequenceOrder = maxSequence + 1
        
        // Create location data - using same location for both actual and known (simplified for bookmarks)
        let locationData = LocationData(
            latitude: location.latitude,
            longitude: location.longitude,
            address: nil,
            city: nil,
            country: nil
        )
        
        // Prepare bookmark data for insertion
        struct WaypointInsert: Codable {
            let id: String
            let route_id: String
            let user_id: String
            let name: String
            let known_location: LocationData
            let actual_location: LocationData
            let sequence_order: Int
            let arrival_time: String
            let created_at: String
            let updated_at: String
        }
        
        let newWaypointId = UUID()
        let now = Date()
        let waypointInsert = WaypointInsert(
            id: newWaypointId.uuidString,
            route_id: routeId.uuidString,
            user_id: session.user.id.uuidString,
            name: name,
            known_location: locationData,
            actual_location: locationData,
            sequence_order: newSequenceOrder,
            arrival_time: ISO8601DateFormatter().string(from: now),
            created_at: ISO8601DateFormatter().string(from: now),
            updated_at: ISO8601DateFormatter().string(from: now)
        )
        
        // Insert into database
        _ = try await SupabaseManager.shared.client
            .from("waypoints")
            .insert(waypointInsert)
            .execute()
        
        // Create the bookmark object
        let newWaypoint = Waypoint(
            id: newWaypointId,
            routeId: routeId,
            userId: session.user.id,
            name: name,
            knownLocation: locationData,
            actualLocation: locationData,
            granularityLevel: "precise",
            sequenceOrder: newSequenceOrder,
            arrivalTime: now,
            departureTime: nil,
            city: nil,
            areaCode: nil,
            country: nil,
            notes: nil,
            createdAt: now,
            updatedAt: now
        )
        
        // Add to local list and sort
        await MainActor.run {
            self.waypoints.append(newWaypoint)
            self.waypoints.sort { $0.sequenceOrder < $1.sequenceOrder }
        }
        
        print("✅ Created bookmark: \(name) at sequence \(newSequenceOrder)")
        
        return newWaypoint
    }
    
    private func getOrCreateMainRoute(for userId: UUID) async throws -> UUID {
        // Check if user has a main route
        let response = try await SupabaseManager.shared.client
            .from("routes")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .limit(1)
            .execute()
        
        if let existingRoutes = try? JSONDecoder().decode([[String: String]].self, from: response.data),
           let firstRoute = existingRoutes.first,
           let routeIdString = firstRoute["id"],
           let routeId = UUID(uuidString: routeIdString) {
            return routeId
        }
        
        // Create a new route if none exists
        struct RouteInsert: Codable {
            let id: String
            let user_id: String
            let name: String
            let description: String?
            let status: String
            let privacy_level: String
            let created_at: String
            let updated_at: String
        }
        
        let newRouteId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())
        
        let newRoute = RouteInsert(
            id: newRouteId.uuidString,
            user_id: userId.uuidString,
            name: "My Journey",
            description: "Main travel route",
            status: "active",
            privacy_level: "private",
            created_at: now,
            updated_at: now
        )
        
        _ = try await SupabaseManager.shared.client
            .from("routes")
            .insert(newRoute)
            .execute()
        
        print("✅ Created main route for user")
        
        return newRouteId
    }
}

enum WaypointError: Error {
    case routeCreationFailed
}