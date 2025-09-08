import Foundation
import Supabase
import Auth
import Storage
import Realtime
import PostgREST

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // Hardcoded values for development - in production these should come from environment variables
        let supabaseURL = "https://bmhqpuppfvqxyclnkhsw.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJtaHFwdXBwZnZxeHljbG5raHN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcxOTQ4MjAsImV4cCI6MjA3Mjc3MDgyMH0.5S4EL-2FTEn2cquAAFXqMU-pTTtITlW2ADRJy3x6EzQ"
        
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL: \(supabaseURL)")
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey
        )
        
        print("SupabaseManager initialized with URL: \(supabaseURL)")
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

struct UserProfile: Codable {
    let id: UUID
    let phone: String
    let name: String
    let photoURL: String?
    let location: LocationData?
    let skills: [String]?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
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

struct LocationData: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let address: String?
    let city: String?
    let country: String?
}