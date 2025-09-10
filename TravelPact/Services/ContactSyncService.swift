import SwiftUI
import Contacts
import Supabase

// MARK: - Contact Sync Service
@MainActor
class ContactSyncService: ObservableObject {
    static let shared = ContactSyncService()
    
    @Published var contacts: [TravelPactContact] = []
    @Published var hasPermission = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let contactStore = CNContactStore()
    private let userDefaults = UserDefaults.standard
    private let contactsKey = "CachedTravelPactContacts"
    
    private init() {
        loadCachedContacts()
    }
    
    // MARK: - Permission Management
    func requestContactsPermission() async -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            hasPermission = true
            return true
        case .notDetermined:
            do {
                let granted = try await contactStore.requestAccess(for: .contacts)
                hasPermission = granted
                return granted
            } catch {
                print("❌ Contact permission error: \(error)")
                hasPermission = false
                return false
            }
        case .denied, .restricted:
            hasPermission = false
            return false
        @unknown default:
            hasPermission = false
            return false
        }
    }
    
    // MARK: - Contact Sync
    func syncContacts() async {
        guard hasPermission else {
            errorMessage = "Contact access not granted"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch device contacts
            let deviceContacts = try await fetchDeviceContacts()
            print("📱 Found \(deviceContacts.count) device contacts")
            
            // Match with TravelPact users
            let matchedContacts = try await matchWithTravelPactUsers(deviceContacts)
            print("🔗 Matched \(matchedContacts.filter { $0.hasAccount }.count) TravelPact users")
            
            // Update local storage
            await updateLocalContacts(matchedContacts)
            
            contacts = matchedContacts.sorted { $0.displayName < $1.displayName }
            
            // Save to cache
            saveCachedContacts()
            
        } catch {
            print("❌ Contact sync error: \(error)")
            errorMessage = "Failed to sync contacts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Cache Management
    private func saveCachedContacts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contacts)
            userDefaults.set(data, forKey: contactsKey)
            print("💾 Saved \(contacts.count) contacts to cache")
        } catch {
            print("❌ Failed to cache contacts: \(error)")
        }
    }
    
    private func loadCachedContacts() {
        guard let data = userDefaults.data(forKey: contactsKey) else {
            print("📱 No cached contacts found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            contacts = try decoder.decode([TravelPactContact].self, from: data)
            print("✅ Loaded \(contacts.count) contacts from cache")
            
            // Check permissions
            hasPermission = CNContactStore.authorizationStatus(for: .contacts) == .authorized
        } catch {
            print("❌ Failed to load cached contacts: \(error)")
        }
    }
    
    private func fetchDeviceContacts() async throws -> [CNContact] {
        let keysToFetch = [
            CNContactIdentifierKey,
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactImageDataKey,
            CNContactOrganizationNameKey,
            CNContactNicknameKey
        ] as [CNKeyDescriptor]
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var contacts: [CNContact] = []
                    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                    
                    try self.contactStore.enumerateContacts(with: request) { contact, _ in
                        // Only include contacts with phone numbers or emails
                        if !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty {
                            contacts.append(contact)
                        }
                    }
                    
                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func matchWithTravelPactUsers(_ deviceContacts: [CNContact]) async throws -> [TravelPactContact] {
        var travelPactContacts: [TravelPactContact] = []
        
        for contact in deviceContacts {
            // Build name more carefully, handling empty names
            var nameParts: [String] = []
            if !contact.givenName.isEmpty {
                nameParts.append(contact.givenName)
            }
            if !contact.familyName.isEmpty {
                nameParts.append(contact.familyName)
            }
            
            var name = nameParts.joined(separator: " ")
            
            // If still no name, try to use company or nickname
            if name.isEmpty {
                if !contact.organizationName.isEmpty {
                    name = contact.organizationName
                } else if !contact.nickname.isEmpty {
                    name = contact.nickname
                }
            }
            
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
            let emails = contact.emailAddresses.map { String($0.value) }
            
            // Try to match with existing TravelPact users by phone or email
            var matchedUser: (userId: UUID, hasAccount: Bool, photoURL: String?, latestWaypointId: UUID?) = (
                userId: UUID(),
                hasAccount: false,
                photoURL: nil,
                latestWaypointId: nil
            )
            
            // Check phone numbers
            for phoneNumber in phoneNumbers {
                if let userMatch = try await checkTravelPactUser(phone: phoneNumber) {
                    matchedUser = userMatch
                    break
                }
            }
            
            // If no phone match, check emails (if implemented)
            if !matchedUser.hasAccount {
                for email in emails {
                    if let userMatch = try await checkTravelPactUser(email: email) {
                        matchedUser = userMatch
                        break
                    }
                }
            }
            
            let travelPactContact = TravelPactContact(
                id: matchedUser.hasAccount ? matchedUser.userId : UUID(),
                name: name,
                phoneNumber: phoneNumbers.first,
                email: emails.first,
                hasAccount: matchedUser.hasAccount,
                userId: matchedUser.hasAccount ? matchedUser.userId : nil,
                photoURL: matchedUser.photoURL,
                latestWaypointId: matchedUser.latestWaypointId,
                contactIdentifier: contact.identifier
            )
            
            travelPactContacts.append(travelPactContact)
        }
        
        return travelPactContacts
    }
    
    private func checkTravelPactUser(phone: String) async throws -> (userId: UUID, hasAccount: Bool, photoURL: String?, latestWaypointId: UUID?)? {
        // Clean phone number for matching
        let cleanedPhone = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        let response = try await SupabaseManager.shared.client
            .from("profiles")
            .select("id, name, photo_url")
            .eq("phone", value: cleanedPhone)
            .limit(1)
            .execute()
        
        let profileData = response.data
        if let profiles = try? JSONDecoder().decode([UserProfile].self, from: profileData),
           let profile = profiles.first {
            
            // Get their latest waypoint for globe viewing
            let latestWaypoint = try? await getLatestWaypoint(for: profile.id)
            
            return (
                userId: profile.id,
                hasAccount: true,
                photoURL: profile.photoURL,
                latestWaypointId: latestWaypoint?.id
            )
        }
        
        return nil
    }
    
    private func checkTravelPactUser(email: String) async throws -> (userId: UUID, hasAccount: Bool, photoURL: String?, latestWaypointId: UUID?)? {
        // For future implementation if email matching is needed
        return nil
    }
    
    private func getLatestWaypoint(for userId: UUID) async throws -> SimpleWaypoint? {
        let response = try await SupabaseManager.shared.client
            .from("waypoints")
            .select("id, name, known_location, arrival_time")
            .eq("user_id", value: userId.uuidString)
            .order("arrival_time", ascending: false)
            .limit(1)
            .execute()
        
        let data = response.data
        if let waypoints = try? JSONDecoder().decode([SimpleWaypoint].self, from: data),
           let latest = waypoints.first {
            return latest
        }
        
        return nil
    }
    
    private func updateLocalContacts(_ contacts: [TravelPactContact]) async {
        // Update connections table
        for contact in contacts where contact.hasAccount {
            do {
                let session = try await SupabaseManager.shared.auth.session
                
                struct ConnectionInsert: Codable {
                    let user_id: String
                    let connection_user_id: String?
                    let name: String
                    let has_account: Bool
                    let connection_type: String
                    let created_at: String
                    let updated_at: String
                }
                
                let connectionData = ConnectionInsert(
                    user_id: session.user.id.uuidString,
                    connection_user_id: contact.userId?.uuidString,
                    name: contact.name,
                    has_account: contact.hasAccount,
                    connection_type: "accepted", // Auto-accept synced contacts
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                try await SupabaseManager.shared.client
                    .from("connections")
                    .upsert(connectionData)
                    .execute()
                
            } catch {
                print("⚠️ Failed to update connection for \(contact.name): \(error)")
            }
        }
    }
}

// MARK: - Helper Models
struct SimpleWaypoint: Codable {
    let id: UUID
    let name: String
    let knownLocation: LocationData?
    let arrivalTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case knownLocation = "known_location"
        case arrivalTime = "arrival_time"
    }
}

