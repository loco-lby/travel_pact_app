import SwiftUI
import Supabase
import Realtime
import CoreLocation

// MARK: - Pact Service
@MainActor
class PactService: ObservableObject {
    static let shared = PactService()
    
    @Published var myPacts: [PactWithMembers] = []
    @Published var invitations: [PactInvitation] = []
    @Published var activeLivePacts: [TravelPact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseManager.shared
    private var realtimeChannel: RealtimeChannelV2?
    
    private init() {
        Task {
            await loadMyPacts()
            await loadInvitations()
            await setupRealtimeSubscription()
        }
    }
    
    // MARK: - Pact Creation
    func createPact(
        name: String,
        description: String?,
        type: PactType,
        routeId: UUID? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        invitedContacts: [TravelPactContact]
    ) async throws -> TravelPact {
        let session = try await supabase.auth.session
        
        // Create pact record
        struct PactInsert: Codable {
            let id: String
            let creator_id: String
            let name: String
            let description: String?
            let pact_type: String
            let route_id: String?
            let start_date: String
            let end_date: String?
            let privacy_level: String
            let is_active: Bool
            let created_at: String
            let updated_at: String
        }
        
        let pactId = UUID()
        let now = ISO8601DateFormatter().string(from: Date())
        
        let pactInsert = PactInsert(
            id: pactId.uuidString,
            creator_id: session.user.id.uuidString,
            name: name,
            description: description,
            pact_type: type.rawValue,
            route_id: routeId?.uuidString,
            start_date: ISO8601DateFormatter().string(from: startDate),
            end_date: endDate != nil ? ISO8601DateFormatter().string(from: endDate!) : nil,
            privacy_level: "pact_members",
            is_active: true,
            created_at: now,
            updated_at: now
        )
        
        let pactResponse = try await supabase.client
            .from("pacts")
            .insert(pactInsert)
            .select()
            .single()
            .execute()
        
        let createdPact = try JSONDecoder().decode(TravelPact.self, from: pactResponse.data)
        
        // Add creator as member
        try await addPactMember(
            pactId: pactId,
            userId: session.user.id,
            name: session.user.email ?? "You",
            role: "creator",
            status: .accepted
        )
        
        // Invite contacts
        for contact in invitedContacts {
            if contact.hasAccount, let userId = contact.userId {
                // App user - send in-app invitation
                try await inviteAppUser(
                    pactId: pactId,
                    userId: userId,
                    name: contact.displayName
                )
            } else if let phoneNumber = contact.phoneNumber {
                // Non-app user - send SMS invitation
                await inviteNonAppUser(
                    pactId: pactId,
                    phoneNumber: phoneNumber,
                    name: contact.displayName,
                    pactName: name
                )
            }
        }
        
        // Reload pacts
        await loadMyPacts()
        
        return createdPact
    }
    
    // MARK: - Member Management
    private func addPactMember(
        pactId: UUID,
        userId: UUID?,
        phoneNumber: String? = nil,
        name: String,
        role: String,
        status: PactMemberStatus
    ) async throws {
        let session = try await supabase.auth.session
        
        struct MemberInsert: Codable {
            let id: String
            let pact_id: String
            let user_id: String?
            let phone_number: String?
            let name: String
            let role: String
            let status: String
            let joined_at: String?
            let invited_at: String
            let invited_by: String
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        let memberInsert = MemberInsert(
            id: UUID().uuidString,
            pact_id: pactId.uuidString,
            user_id: userId?.uuidString,
            phone_number: phoneNumber,
            name: name,
            role: role,
            status: status.rawValue,
            joined_at: status == .accepted ? now : nil,
            invited_at: now,
            invited_by: session.user.id.uuidString
        )
        
        try await supabase.client
            .from("pact_members")
            .insert(memberInsert)
            .execute()
    }
    
    private func inviteAppUser(pactId: UUID, userId: UUID, name: String) async throws {
        try await addPactMember(
            pactId: pactId,
            userId: userId,
            name: name,
            role: "member",
            status: .pending
        )
        
        // Could send push notification here
        print("📱 Invited app user \(name) to pact")
    }
    
    private func inviteNonAppUser(
        pactId: UUID,
        phoneNumber: String,
        name: String,
        pactName: String
    ) async {
        do {
            try await addPactMember(
                pactId: pactId,
                userId: nil,
                phoneNumber: phoneNumber,
                name: name,
                role: "member",
                status: .pending
            )
            
            // Send SMS invitation
            // In production, this would use a service like Twilio
            print("📱 SMS invitation would be sent to \(phoneNumber)")
            print("Message: \(name), you've been invited to join '\(pactName)' on TravelPact. Download the app to join!")
            
        } catch {
            print("❌ Failed to invite non-app user: \(error)")
        }
    }
    
    // MARK: - Accept/Decline Invitations
    func acceptInvitation(_ invitationId: UUID) async throws {
        let session = try await supabase.auth.session
        
        struct StatusUpdate: Codable {
            let status: String
            let joined_at: String
        }
        
        let update = StatusUpdate(
            status: PactMemberStatus.accepted.rawValue,
            joined_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabase.client
            .from("pact_members")
            .update(update)
            .eq("id", value: invitationId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        await loadInvitations()
        await loadMyPacts()
    }
    
    func declineInvitation(_ invitationId: UUID) async throws {
        let session = try await supabase.auth.session
        
        struct StatusUpdate: Codable {
            let status: String
        }
        
        let update = StatusUpdate(status: PactMemberStatus.declined.rawValue)
        
        try await supabase.client
            .from("pact_members")
            .update(update)
            .eq("id", value: invitationId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        await loadInvitations()
    }
    
    // MARK: - Leave Pact
    func leavePact(_ pactId: UUID) async throws {
        let session = try await supabase.auth.session
        
        struct StatusUpdate: Codable {
            let status: String
        }
        
        let update = StatusUpdate(status: PactMemberStatus.left.rawValue)
        
        try await supabase.client
            .from("pact_members")
            .update(update)
            .eq("pact_id", value: pactId.uuidString)
            .eq("user_id", value: session.user.id.uuidString)
            .execute()
        
        await loadMyPacts()
    }
    
    // MARK: - End Pact
    func endPact(_ pactId: UUID) async throws {
        struct PactUpdate: Codable {
            let is_active: Bool
            let end_date: String
            let updated_at: String
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        let update = PactUpdate(
            is_active: false,
            end_date: now,
            updated_at: now
        )
        
        try await supabase.client
            .from("pacts")
            .update(update)
            .eq("id", value: pactId.uuidString)
            .execute()
        
        await loadMyPacts()
    }
    
    // MARK: - Load Data
    func loadMyPacts() async {
        do {
            let session = try await supabase.auth.session
            
            // Get pacts where user is a member (including creator)
            let memberResponse = try await supabase.client
                .from("pact_members")
                .select("""
                    pact_id,
                    pacts!inner(
                        id,
                        creator_id,
                        name,
                        description,
                        pact_type,
                        route_id,
                        start_date,
                        end_date,
                        privacy_level,
                        is_active,
                        created_at,
                        updated_at
                    )
                """)
                .eq("user_id", value: session.user.id.uuidString)
                .in("status", values: ["accepted", "pending"])
                .execute()
            
            // Parse pacts
            // This would need more complex parsing in production
            myPacts = []
            
            // Filter active live pacts
            activeLivePacts = myPacts
                .map { $0.pact }
                .filter { $0.isLive }
            
        } catch {
            print("❌ Failed to load pacts: \(error)")
            errorMessage = "Failed to load pacts"
        }
    }
    
    func loadInvitations() async {
        do {
            let session = try await supabase.auth.session
            
            let invitationResponse = try await supabase.client
                .from("pact_members")
                .select("""
                    id,
                    pact_id,
                    status,
                    invited_at,
                    invited_by,
                    pacts!inner(
                        id,
                        name,
                        description,
                        pact_type,
                        start_date,
                        end_date,
                        is_active
                    ),
                    profiles!invited_by(
                        id,
                        name,
                        photo_url
                    )
                """)
                .eq("user_id", value: session.user.id.uuidString)
                .eq("status", value: "pending")
                .execute()
            
            // Parse invitations
            // This would need proper parsing in production
            invitations = []
            
        } catch {
            print("❌ Failed to load invitations: \(error)")
        }
    }
    
    // MARK: - Live Location Updates
    func updateLiveLocation(_ location: CLLocation, for pactId: UUID) async throws {
        let session = try await supabase.auth.session
        
        struct LocationUpdate: Codable {
            let id: String
            let pact_id: String
            let user_id: String
            let location: LocationData
            let timestamp: String
            let accuracy: Double
            let heading: Double?
            let speed: Double?
        }
        
        let locationData = LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            address: nil,
            city: nil,
            country: nil
        )
        
        let update = LocationUpdate(
            id: UUID().uuidString,
            pact_id: pactId.uuidString,
            user_id: session.user.id.uuidString,
            location: locationData,
            timestamp: ISO8601DateFormatter().string(from: location.timestamp),
            accuracy: location.horizontalAccuracy,
            heading: location.course >= 0 ? location.course : nil,
            speed: location.speed >= 0 ? location.speed : nil
        )
        
        try await supabase.client
            .from("pact_location_updates")
            .insert(update)
            .execute()
    }
    
    // MARK: - Realtime Updates
    private func setupRealtimeSubscription() async {
        do {
            let session = try await supabase.auth.session
            
            realtimeChannel = supabase.client.realtimeV2.channel("pact_updates")
            
            // Subscribe to pact member changes
            let _ = await realtimeChannel?
                .onPostgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "pact_members",
                    filter: "user_id=eq.\(session.user.id.uuidString)"
                ) { action in
                    Task { @MainActor in
                        await self.loadMyPacts()
                        await self.loadInvitations()
                    }
                }
            
            await realtimeChannel?.subscribe()
            
        } catch {
            print("❌ Failed to setup realtime subscription: \(error)")
        }
    }
    
    deinit {
        Task {
            await realtimeChannel?.unsubscribe()
        }
    }
}