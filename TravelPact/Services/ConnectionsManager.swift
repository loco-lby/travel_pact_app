import Foundation
import CoreLocation
import Combine

struct Connection: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let connectionUserId: UUID?
    let name: String
    let assignedLocation: LocationData?
    let assignedLocationName: String?
    let actualKnownLocation: LocationData?
    let actualKnownLocationName: String?
    let locationSource: String?
    let hasAccount: Bool
    let connectionType: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties for display
    var displayCoordinate: CLLocationCoordinate2D? {
        // Prefer actual location if they're an app user, otherwise use assigned
        if hasAccount, let actual = actualKnownLocation {
            return CLLocationCoordinate2D(
                latitude: actual.latitude,
                longitude: actual.longitude
            )
        } else if let assigned = assignedLocation {
            return CLLocationCoordinate2D(
                latitude: assigned.latitude,
                longitude: assigned.longitude
            )
        }
        return nil
    }
    
    var displayLocationName: String? {
        if hasAccount, let actualName = actualKnownLocationName {
            return actualName
        } else if let assignedName = assignedLocationName {
            return assignedName
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case connectionUserId = "connection_user_id"
        case name
        case assignedLocation = "assigned_location"
        case assignedLocationName = "assigned_location_name"
        case actualKnownLocation = "actual_known_location"
        case actualKnownLocationName = "actual_known_location_name"
        case locationSource = "location_source"
        case hasAccount = "has_account"
        case connectionType = "connection_type"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

class ConnectionsManager: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var visibleConnections: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Filter visible connections based on type
        $connections
            .map { connections in
                connections.filter { $0.connectionType != "blocked" }
            }
            .assign(to: &$visibleConnections)
    }
    
    // MARK: - Load Connections
    
    func loadConnections() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let session = try await SupabaseManager.shared.auth.session
                
                let response = try await SupabaseManager.shared.client
                    .from("connections")
                    .select()
                    .eq("user_id", value: session.user.id.uuidString)
                    .order("name", ascending: true)
                    .execute()
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let loadedConnections = try decoder.decode([Connection].self, from: response.data)
                
                await MainActor.run {
                    self.connections = loadedConnections
                    self.isLoading = false
                }
                
                print("✅ Loaded \(loadedConnections.count) connections")
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load connections: \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("❌ Error loading connections: \(error)")
            }
        }
    }
    
    // MARK: - Add Connection
    
    func addConnection(
        name: String,
        location: CLLocationCoordinate2D?,
        locationName: String?,
        notes: String?
    ) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        struct ConnectionInsert: Codable {
            let user_id: String
            let name: String
            let assigned_location: LocationData?
            let assigned_location_name: String?
            let location_source: String?
            let has_account: Bool
            let connection_type: String
            let notes: String?
            let created_at: String
            let updated_at: String
        }
        
        var assignedLocationData: LocationData? = nil
        if let location = location {
            assignedLocationData = LocationData(
                latitude: location.latitude,
                longitude: location.longitude,
                address: locationName,
                city: nil,
                country: nil
            )
        }
        
        let connection = ConnectionInsert(
            user_id: session.user.id.uuidString,
            name: name,
            assigned_location: assignedLocationData,
            assigned_location_name: locationName,
            location_source: assignedLocationData != nil ? "assigned" : nil,
            has_account: false,
            connection_type: "accepted",
            notes: notes,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await SupabaseManager.shared.client
            .from("connections")
            .insert(connection)
            .execute()
        
        // Reload connections
        loadConnections()
    }
    
    // MARK: - Update Connection
    
    func updateConnectionLocation(
        connectionId: UUID,
        location: CLLocationCoordinate2D,
        locationName: String
    ) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        struct LocationUpdate: Codable {
            let assigned_location: LocationData
            let assigned_location_name: String
            let location_source: String
            let updated_at: String
        }
        
        let locationData = LocationData(
            latitude: location.latitude,
            longitude: location.longitude,
            address: locationName,
            city: nil,
            country: nil
        )
        
        let update = LocationUpdate(
            assigned_location: locationData,
            assigned_location_name: locationName,
            location_source: "assigned",
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await SupabaseManager.shared.client
            .from("connections")
            .update(update)
            .eq("id", value: connectionId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        // Reload connections
        loadConnections()
    }
    
    // MARK: - Delete Connection
    
    func deleteConnection(connectionId: UUID) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        try await SupabaseManager.shared.client
            .from("connections")
            .delete()
            .eq("id", value: connectionId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        // Remove from local array
        await MainActor.run {
            connections.removeAll { $0.id == connectionId }
        }
    }
    
    // MARK: - Search for App Users
    
    func searchAppUsers(query: String) async throws -> [UserProfile] {
        guard !query.isEmpty else { return [] }
        
        let response = try await SupabaseManager.shared.client
            .from("profiles")
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(10)
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([UserProfile].self, from: response.data)
    }
    
    // MARK: - Connect with App User
    
    func connectWithAppUser(userId: UUID, userName: String) async throws {
        let session = try await SupabaseManager.shared.auth.session
        
        // Check if connection already exists
        let existingResponse = try await SupabaseManager.shared.client
            .from("connections")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("connection_user_id", value: userId.uuidString)
            .execute()
        
        // Check if we got any results
        if let data = try? JSONSerialization.jsonObject(with: existingResponse.data) as? [[String: Any]],
           !data.isEmpty {
            throw NSError(domain: "ConnectionsManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Connection already exists"
            ])
        }
        
        struct AppUserConnection: Codable {
            let user_id: String
            let connection_user_id: String
            let name: String
            let location_source: String
            let has_account: Bool
            let connection_type: String
            let created_at: String
            let updated_at: String
        }
        
        let connection = AppUserConnection(
            user_id: session.user.id.uuidString,
            connection_user_id: userId.uuidString,
            name: userName,
            location_source: "actual",
            has_account: true,
            connection_type: "accepted",
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await SupabaseManager.shared.client
            .from("connections")
            .insert(connection)
            .execute()
        
        // Reload connections
        loadConnections()
    }
}