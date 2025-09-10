import Foundation
import CoreLocation

// MARK: - Pact Models
enum PactType: String, Codable, CaseIterable {
    case timeline = "timeline"  // For sharing completed journeys
    case live = "live"          // For real-time location sharing
    
    var displayName: String {
        switch self {
        case .timeline:
            return "Timeline Pact"
        case .live:
            return "Live Pact"
        }
    }
    
    var description: String {
        switch self {
        case .timeline:
            return "Share your completed journey with selected contacts"
        case .live:
            return "Share your location in real-time during your travels"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline:
            return "clock.arrow.circlepath"
        case .live:
            return "location.circle.fill"
        }
    }
}

struct TravelPact: Identifiable, Codable {
    let id: UUID
    let creatorId: UUID
    let name: String
    let description: String?
    let pactType: PactType
    let routeId: UUID?  // For timeline pacts
    let startDate: Date
    let endDate: Date?
    let privacyLevel: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties
    var isLive: Bool {
        pactType == .live && isActive
    }
    
    var isTimeline: Bool {
        pactType == .timeline
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case name
        case description
        case pactType = "pact_type"
        case routeId = "route_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case privacyLevel = "privacy_level"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PactMember: Identifiable, Codable {
    let id: UUID
    let pactId: UUID
    let userId: UUID?  // nil for non-app users
    let phoneNumber: String?  // For SMS invites
    let name: String
    let role: String  // "creator", "member"
    let status: PactMemberStatus
    let joinedAt: Date?
    let invitedAt: Date
    let invitedBy: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case pactId = "pact_id"
        case userId = "user_id"
        case phoneNumber = "phone_number"
        case name
        case role
        case status
        case joinedAt = "joined_at"
        case invitedAt = "invited_at"
        case invitedBy = "invited_by"
    }
}

enum PactMemberStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case left = "left"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Joined"
        case .declined:
            return "Declined"
        case .left:
            return "Left"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .accepted:
            return "green"
        case .declined:
            return "red"
        case .left:
            return "gray"
        }
    }
}

// MARK: - Pact Creation Models
struct CreatePactRequest: Codable {
    let name: String
    let description: String?
    let pactType: PactType
    let routeId: UUID?
    let startDate: Date
    let endDate: Date?
    let privacyLevel: String
    let invitedMembers: [InvitedMember]
    
    struct InvitedMember: Codable {
        let userId: UUID?
        let phoneNumber: String?
        let name: String
    }
}

// MARK: - Pact Location Update (for Live Pacts)
struct PactLocationUpdate: Codable {
    let pactId: UUID
    let userId: UUID
    let location: LocationData
    let timestamp: Date
    let accuracy: Double
    let heading: Double?
    let speed: Double?
    
    enum CodingKeys: String, CodingKey {
        case pactId = "pact_id"
        case userId = "user_id"
        case location
        case timestamp
        case accuracy
        case heading
        case speed
    }
}

// MARK: - Pact Views
struct PactWithMembers: Identifiable, Codable {
    let pact: TravelPact
    let members: [PactMember]
    let creator: UserProfile?
    
    var id: UUID { pact.id }
    
    var acceptedMembers: [PactMember] {
        members.filter { $0.status == .accepted }
    }
    
    var pendingMembers: [PactMember] {
        members.filter { $0.status == .pending }
    }
    
    var memberCount: Int {
        acceptedMembers.count
    }
}

// MARK: - Pact Invitation
struct PactInvitation: Identifiable, Codable {
    let id: UUID
    let pact: TravelPact
    let invitedBy: UserProfile
    let invitedAt: Date
    let status: PactMemberStatus
    let message: String?
    
    var isActive: Bool {
        status == .pending
    }
}