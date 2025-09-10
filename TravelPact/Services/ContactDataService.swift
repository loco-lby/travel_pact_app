import SwiftUI
import Supabase
import CoreLocation

// MARK: - Contact Data Models
struct ContactRoute: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let waypoints: [ContactWaypoint]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case waypoints
    }
}

struct ContactWaypoint: Identifiable, Codable {
    let id: UUID
    let name: String
    let location: ContactTravelLocation
    let arrivalTime: Date?
    let departureTime: Date?
    let city: String?
    let areaCode: String?  // Postal/ZIP code
    let country: String?
    let sequenceOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case location = "known_location"
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case city
        case areaCode = "area_code"
        case country
        case sequenceOrder = "sequence_order"
    }
}

struct ContactTravelLocation: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Contact Data Service
@MainActor
class ContactDataService: ObservableObject {
    @Published var routes: [ContactRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadContactData(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check privacy settings first
            let canView = try await checkViewPermission(userId: userId)
            guard canView else {
                errorMessage = "This user's travel history is private"
                isLoading = false
                return
            }
            
            // Load routes and waypoints
            let contactRoutes = try await fetchContactRoutes(userId: userId)
            
            routes = contactRoutes.sorted { route1, route2 in
                // Sort by most recent waypoint first
                let date1 = route1.waypoints.compactMap { $0.arrivalTime }.max() ?? Date.distantPast
                let date2 = route2.waypoints.compactMap { $0.arrivalTime }.max() ?? Date.distantPast
                return date1 > date2
            }
            
        } catch {
            print("❌ Error loading contact data: \(error)")
            errorMessage = "Failed to load travel data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func checkViewPermission(userId: UUID) async throws -> Bool {
        // Check if user has shared their routes with current user through connections or pacts
        let session = try await SupabaseManager.shared.auth.session
        
        // Check connection relationship
        let connectionResponse = try await SupabaseManager.shared.client
            .from("connections")
            .select("connection_type")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("connection_user_id", value: userId.uuidString)
            .eq("connection_type", value: "accepted")
            .limit(1)  // Limit to prevent multiple row error
            .execute()
        
        let data = connectionResponse.data
        if let connections = try? JSONDecoder().decode([ConnectionStatus].self, from: data),
           !connections.isEmpty {
            return true
        }
        
        // Could also check for shared pacts here
        // For now, allow viewing if they're in our connections
        
        // Check if their routes are public
        let publicRoutesResponse = try await SupabaseManager.shared.client
            .from("routes")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("privacy_level", value: "public")
            .limit(1)
            .execute()
        
        let publicData = publicRoutesResponse.data
        if let routes = try? JSONDecoder().decode([RouteCheck].self, from: publicData),
           !routes.isEmpty {
            return true
        }
        
        return false
    }
    
    private func fetchContactRoutes(userId: UUID) async throws -> [ContactRoute] {
        // Fetch routes with waypoints
        let routesResponse = try await SupabaseManager.shared.client
            .from("routes")
            .select("""
                id,
                name,
                description,
                start_date,
                end_date,
                waypoints!inner(
                    id,
                    name,
                    known_location,
                    arrival_time,
                    departure_time,
                    city,
                    area_code,
                    country,
                    sequence_order
                )
            """)
            .eq("user_id", value: userId.uuidString)
            .in("privacy_level", values: ["friends", "public"]) // Only show non-private routes
            .order("start_date", ascending: false)
            .execute()
        
        let data = routesResponse.data
        
        let routeResponses = try JSONDecoder().decode([RouteWithWaypointsResponse].self, from: data)
        
        return routeResponses.compactMap { routeResponse in
            // Convert waypoints
            let unsortedWaypoints: [ContactWaypoint] = routeResponse.waypoints?.compactMap { waypointData in
                guard let locationData = waypointData.knownLocation else { return nil }
                
                return ContactWaypoint(
                    id: waypointData.id,
                    name: waypointData.name,
                    location: ContactTravelLocation(
                        latitude: locationData.latitude,
                        longitude: locationData.longitude
                    ),
                    arrivalTime: waypointData.arrivalTime,
                    departureTime: waypointData.departureTime,
                    city: waypointData.city,
                    areaCode: waypointData.areaCode,
                    country: waypointData.country,
                    sequenceOrder: waypointData.sequenceOrder
                )
            } ?? []
            
            let waypoints = unsortedWaypoints.sorted(by: { w1, w2 in
                w1.sequenceOrder < w2.sequenceOrder
            })
            
            guard !waypoints.isEmpty else { return nil }
            
            return ContactRoute(
                id: routeResponse.id,
                name: routeResponse.name,
                description: routeResponse.description,
                startDate: routeResponse.startDate,
                endDate: routeResponse.endDate,
                waypoints: waypoints
            )
        }
    }
}

// MARK: - Response Models
struct ConnectionStatus: Codable {
    let connectionType: String
    
    enum CodingKeys: String, CodingKey {
        case connectionType = "connection_type"
    }
}

struct RouteCheck: Codable {
    let id: UUID
}

struct RouteWithWaypointsResponse: Codable {
    let id: UUID
    let name: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let waypoints: [WaypointInRouteResponse]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case waypoints
    }
}

struct WaypointInRouteResponse: Codable {
    let id: UUID
    let name: String
    let knownLocation: LocationData?
    let arrivalTime: Date?
    let departureTime: Date?
    let city: String?
    let areaCode: String?
    let country: String?
    let sequenceOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case knownLocation = "known_location"
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case city
        case areaCode = "area_code"
        case country
        case sequenceOrder = "sequence_order"
    }
}

// MARK: - Errors
enum ContactDataError: Error {
    case noData
    case permissionDenied
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .noData:
            return "No travel data found"
        case .permissionDenied:
            return "Permission denied to view travel data"
        case .invalidData:
            return "Invalid travel data format"
        }
    }
}