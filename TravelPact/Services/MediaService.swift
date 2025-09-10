import Foundation
import SwiftUI
import Supabase

class MediaService: ObservableObject {
    static let shared = MediaService()
    private let supabase = SupabaseManager.shared
    
    @Published var waypointMediaCounts: [UUID: Int] = [:]
    @Published var waypointThumbnails: [UUID: String] = [:]
    
    private init() {}
    
    func loadMediaForWaypoints(_ waypoints: [Waypoint]) async {
        for waypoint in waypoints {
            await loadMediaCount(for: waypoint.id)
            await loadThumbnail(for: waypoint.id)
        }
    }
    
    func loadMediaCount(for waypointId: UUID) async {
        do {
            let response = try await supabase.client
                .from("media")
                .select("id", head: false, count: .exact)
                .eq("waypoint_id", value: waypointId.uuidString)
                .neq("privacy_level", value: "trash")
                .execute()
            
            print("📊 Media count for waypoint \(waypointId): \(response.count ?? 0)")
            
            if let count = response.count {
                await MainActor.run {
                    self.waypointMediaCounts[waypointId] = count
                }
            }
        } catch {
            print("Error loading media count for waypoint \(waypointId): \(error)")
        }
    }
    
    func loadThumbnail(for waypointId: UUID) async {
        do {
            // Get the first media item for thumbnail
            let response = try await supabase.client
                .from("media")
                .select("id, file_path, storage_bucket, user_id, waypoint_id")
                .eq("waypoint_id", value: waypointId.uuidString)
                .neq("privacy_level", value: "trash")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            struct MediaThumbnail: Codable {
                let id: String
                let file_path: String
                let storage_bucket: String?
                let user_id: String
                let waypoint_id: String
            }
            
            let decoder = JSONDecoder()
            if let media = try? decoder.decode([MediaThumbnail].self, from: response.data).first {
                print("📸 Found media for waypoint \(waypointId): id=\(media.id), path=\(media.file_path)")
                
                // Try thumbnail first, then fall back to full image with signed URL
                let thumbnailPath = "\(media.user_id)/\(media.id)_thumb.jpg"
                print("📸 Trying thumbnail path: \(thumbnailPath)")
                
                // First try to get the thumbnail
                do {
                    let publicURL = try supabase.storage
                        .from("waypoint-thumbnails")
                        .getPublicURL(path: thumbnailPath)
                    
                    print("✅ Got thumbnail URL: \(publicURL.absoluteString)")
                    await MainActor.run {
                        self.waypointThumbnails[waypointId] = publicURL.absoluteString
                    }
                } catch {
                    print("⚠️ Thumbnail not found, falling back to original")
                    // If thumbnail doesn't exist, create a signed URL for the original
                    let originalPath = "\(media.user_id)/\(media.waypoint_id)/\(media.file_path)"
                    print("📸 Trying original path: \(originalPath)")
                    
                    let signedURL = try await supabase.storage
                        .from("waypoint-media")
                        .createSignedURL(path: originalPath, expiresIn: 3600)
                    
                    print("✅ Got signed URL: \(signedURL.absoluteString)")
                    await MainActor.run {
                        self.waypointThumbnails[waypointId] = signedURL.absoluteString
                    }
                }
            }
        } catch {
            print("Error loading thumbnail for waypoint \(waypointId): \(error)")
        }
    }
    
    func getPublicURL(for mediaItem: MediaItem) async -> URL? {
        do {
            if mediaItem.privacyLevel == "public_slideshow" || mediaItem.privacyLevel == "public" {
                // Use public bucket for public media
                let path = "\(mediaItem.userId)/\(mediaItem.id)_thumb.jpg"
                return try supabase.storage
                    .from("waypoint-thumbnails")
                    .getPublicURL(path: path)
            } else {
                // For private media, generate signed URL
                let path = "\(mediaItem.userId)/\(mediaItem.waypointId)/\(mediaItem.filePath)"
                let signedURL = try await supabase.storage
                    .from("waypoint-media")
                    .createSignedURL(path: path, expiresIn: 3600)
                return URL(string: signedURL.absoluteString)
            }
        } catch {
            print("Error generating URL for media: \(error)")
            return nil
        }
    }
    
    func getThumbnailURL(for mediaItem: MediaItem) async -> URL? {
        do {
            // First try to get the thumbnail
            let thumbnailPath = "\(mediaItem.userId)/\(mediaItem.id)_thumb.jpg"
            
            // Try public thumbnail first
            do {
                return try supabase.storage
                    .from("waypoint-thumbnails")
                    .getPublicURL(path: thumbnailPath)
            } catch {
                // If thumbnail doesn't exist, create a signed URL for the original
                let originalPath = "\(mediaItem.userId)/\(mediaItem.waypointId)/\(mediaItem.filePath)"
                let signedURL = try await supabase.storage
                    .from("waypoint-media")
                    .createSignedURL(path: originalPath, expiresIn: 3600)
                return URL(string: signedURL.absoluteString)
            }
        } catch {
            print("Error generating thumbnail URL for media \(mediaItem.id): \(error)")
            return nil
        }
    }
}