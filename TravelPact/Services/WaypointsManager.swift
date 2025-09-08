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
    let region: String?
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
        case region
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
        isLoading = true
        errorMessage = ""
        
        Task {
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
                
                await MainActor.run {
                    self.waypoints = loadedWaypoints
                    self.isLoading = false
                }
                
                print("✅ Loaded \(loadedWaypoints.count) waypoints")
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load waypoints: \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("❌ Error loading waypoints: \(error)")
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
                
                print("✅ Updated waypoint: \(waypoint.name)")
            } catch {
                print("❌ Error updating waypoint: \(error)")
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
        
        // Update sequence orders for remaining waypoints in database
        await reorderWaypoints(afterDeletion: waypoint.sequenceOrder, routeId: waypoint.routeId)
        
        // Remove from local array immediately
        await MainActor.run {
            self.waypoints.removeAll { $0.id == waypoint.id }
            // Update local sequence orders
            for index in waypoints.indices {
                if waypoints[index].routeId == waypoint.routeId && waypoints[index].sequenceOrder > waypoint.sequenceOrder {
                    // Create new waypoint with updated sequence order
                    let wp = waypoints[index]
                    waypoints[index] = Waypoint(
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
                        region: wp.region,
                        country: wp.country,
                        notes: wp.notes,
                        createdAt: wp.createdAt,
                        updatedAt: Date()
                    )
                }
            }
        }
        
        print("✅ Deleted waypoint: \(waypoint.name)")
        
        // Reload to sync with database
        loadWaypoints()
    }
    
    func splitRouteAtWaypoint(_ waypoint: Waypoint) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        // Check if there are waypoints after this one in the same route
        let waypointsAfter = waypoints.filter { 
            $0.routeId == waypoint.routeId && $0.sequenceOrder > waypoint.sequenceOrder 
        }
        
        // Only split if there are waypoints after this one
        if !waypointsAfter.isEmpty {
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
            
            let newRoute = RouteInsert(
                user_id: session.user.id.uuidString,
                name: "Split Route - After \(waypoint.name)",
                description: "Route split from original at \(waypoint.name)",
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
            
            // Update waypoints after the split point to belong to the new route
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
            
            print("✅ Split route at waypoint: \(waypoint.name), moved \(waypointsAfter.count) waypoints to new route")
        }
        
        // Delete the waypoint at the split point
        try await deleteWaypoint(waypoint)
    }
    
    private func reorderWaypoints(afterDeletion deletedOrder: Int, routeId: UUID) async {
        // Update sequence orders for waypoints after the deleted one
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
                print("❌ Error reordering waypoint: \(error)")
            }
        }
    }
}

enum WaypointError: Error {
    case routeCreationFailed
}