import Foundation
import Supabase
import Auth
import Storage
import Realtime
import PostgREST

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    let supabaseURL: String
    
    private init() {
        // Hardcoded values for development - in production these should come from environment variables
        let supabaseURLString = "https://bmhqpuppfvqxyclnkhsw.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJtaHFwdXBwZnZxeHljbG5raHN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcxOTQ4MjAsImV4cCI6MjA3Mjc3MDgyMH0.5S4EL-2FTEn2cquAAFXqMU-pTTtITlW2ADRJy3x6EzQ"
        
        self.supabaseURL = supabaseURLString
        
        guard let url = URL(string: supabaseURLString) else {
            fatalError("Invalid Supabase URL: \(supabaseURLString)")
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey
        )
        
        print("SupabaseManager initialized with URL: \(supabaseURLString)")
    }
    
    var auth: AuthClient {
        return client.auth
    }
    
    var database: PostgrestClient {
        return client.database
    }
    
    var storage: SupabaseStorageClient {
        return client.storage
    }
    
    func signOut() async throws {
        try await auth.signOut()
    }
}

// MARK: - Core Data Models

public struct UserProfile: Codable {
    public let id: UUID
    public let phone: String
    public let name: String
    public let photoURL: String?
    public let location: LocationData?
    public let skills: [String]?
    public let createdAt: Date
    public let updatedAt: Date
    
    public enum CodingKeys: String, CodingKey {
        case id
        case phone
        case name
        case photoURL = "photo_url"
        case location
        case skills
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct LocationData: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    public let city: String?
    public let country: String?
}