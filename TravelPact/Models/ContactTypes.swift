import SwiftUI
import Foundation

// MARK: - Contact Models
struct TravelPactContact: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String?
    let email: String?
    let hasAccount: Bool
    let userId: UUID? // If they have a TravelPact account
    let photoURL: String?
    let latestWaypointId: UUID? // For globe viewing
    
    // Contact info from phone
    let contactIdentifier: String? // CNContact identifier
    
    var displayName: String {
        return name.isEmpty ? (phoneNumber ?? email ?? "Unknown") : name
    }
    
    var bubbleInitials: String {
        // Clean the name first
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanName.isEmpty {
            // Try to use phone or email as fallback
            if let phone = phoneNumber, !phone.isEmpty {
                // Use last 2 digits of phone
                let digits = phone.filter { $0.isNumber }
                if digits.count >= 2 {
                    return String(digits.suffix(2))
                }
            }
            if let email = email, !email.isEmpty {
                // Use first 2 chars of email
                return String(email.prefix(2)).uppercased()
            }
            return "?"
        }
        
        let components = cleanName.components(separatedBy: " ").filter { !$0.isEmpty }
        if components.count >= 2 {
            // Use first letter of first and last name
            let first = String(components[0].prefix(1)).uppercased()
            let last = String(components[components.count - 1].prefix(1)).uppercased()
            return first + last
        } else if components.count == 1 {
            // Use first 2 letters of single name
            let name = components[0]
            if name.count >= 2 {
                return String(name.prefix(2)).uppercased()
            } else {
                return name.uppercased()
            }
        }
        return "?"
    }
}