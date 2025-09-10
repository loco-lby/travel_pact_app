import Foundation
import SwiftUI
import PhotosUI
import Supabase
import CoreImage
import CoreLocation

class MediaUploadService: ObservableObject {
    static let shared = MediaUploadService()
    
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false
    @Published var currentUploadTask: String = ""
    @Published var uploadErrors: [String] = []
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    func uploadPhotosToWaypoint(_ items: [PhotosPickerItem], waypoint: Waypoint) async {
        // Verify user is authenticated
        do {
            let session = try await supabase.auth.session
            print("📱 Uploading as user: \(session.user.id)")
        } catch {
            print("❌ User not authenticated: \(error)")
            await MainActor.run {
                self.uploadErrors.append("You must be logged in to upload photos")
            }
            return
        }
        
        await MainActor.run {
            self.isUploading = true
            self.uploadProgress = 0
            self.uploadErrors.removeAll()
        }
        
        let totalItems = Double(items.count)
        var completedItems = 0.0
        
        for item in items {
            await MainActor.run {
                self.currentUploadTask = "Processing photo \(Int(completedItems) + 1) of \(Int(totalItems))"
            }
            
            do {
                // Load the photo data
                guard let imageData = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run {
                        self.uploadErrors.append("Failed to load photo \(Int(completedItems) + 1)")
                    }
                    continue
                }
                
                // Get photo metadata
                let metadata = await extractPhotoMetadata(from: item)
                
                // Generate unique filename
                let mediaId = UUID()
                let fileName = "\(mediaId).jpg"
                let filePath = "\(waypoint.userId)/\(waypoint.id)/\(fileName)"
                
                print("📁 Upload path: \(filePath)")
                print("📁 User ID: \(waypoint.userId)")
                print("📁 Waypoint ID: \(waypoint.id)")
                
                // Create thumbnail
                let thumbnailData = await createThumbnail(from: imageData)
                let thumbnailPath = "\(waypoint.userId)/\(mediaId)_thumb.jpg"
                
                // Upload original to storage
                await MainActor.run {
                    self.currentUploadTask = "Uploading photo \(Int(completedItems) + 1)"
                }
                
                print("⬆️ Uploading to waypoint-media bucket: \(filePath)")
                _ = try await supabase.storage
                    .from("waypoint-media")
                    .upload(
                        filePath,
                        data: imageData,
                        options: FileOptions(contentType: "image/jpeg")
                    )
                print("✅ Successfully uploaded to waypoint-media")
                
                // Upload thumbnail
                if let thumbnailData = thumbnailData {
                    print("⬆️ Uploading thumbnail to waypoint-thumbnails bucket: \(thumbnailPath)")
                    _ = try await supabase.storage
                        .from("waypoint-thumbnails")
                        .upload(
                            thumbnailPath,
                            data: thumbnailData,
                            options: FileOptions(contentType: "image/jpeg")
                        )
                    print("✅ Successfully uploaded thumbnail")
                } else {
                    print("⚠️ No thumbnail data to upload")
                }
                
                // Create media record in database
                struct MediaInsert: Codable {
                    let id: String
                    let waypoint_id: String
                    let user_id: String
                    let file_path: String
                    let storage_bucket: String
                    let media_type: String
                    let file_size_bytes: Int
                    let mime_type: String
                    let privacy_level: String
                    let taken_at: String?
                    let latitude: Double?
                    let longitude: Double?
                }
                
                let mediaRecord = MediaInsert(
                    id: mediaId.uuidString,
                    waypoint_id: waypoint.id.uuidString,
                    user_id: waypoint.userId.uuidString,
                    file_path: fileName,
                    storage_bucket: "waypoint-media",
                    media_type: "photo",
                    file_size_bytes: imageData.count,
                    mime_type: "image/jpeg",
                    privacy_level: "private",
                    taken_at: metadata?.creationDate?.ISO8601Format(),
                    latitude: metadata?.location?.coordinate.latitude,
                    longitude: metadata?.location?.coordinate.longitude
                )
                
                try await supabase.client
                    .from("media")
                    .insert(mediaRecord)
                    .execute()
                
                completedItems += 1
                await MainActor.run {
                    self.uploadProgress = completedItems / totalItems
                }
                
            } catch {
                print("Error uploading photo: \(error)")
                await MainActor.run {
                    self.uploadErrors.append("Failed to upload photo \(Int(completedItems) + 1): \(error.localizedDescription)")
                }
            }
        }
        
        await MainActor.run {
            self.isUploading = false
            self.currentUploadTask = ""
            if self.uploadErrors.isEmpty {
                self.uploadProgress = 1.0
            }
        }
    }
    
    func uploadAnalyzedPhoto(
        imageData: Data,
        waypoint: Waypoint,
        metadata: PhotoMetadata?,
        privacyLevel: String = "private"
    ) async throws -> UUID {
        let mediaId = UUID()
        let fileName = "\(mediaId).jpg"
        let filePath = "\(waypoint.userId)/\(waypoint.id)/\(fileName)"
        
        // Create thumbnail
        let thumbnailData = await createThumbnail(from: imageData)
        let thumbnailPath = "\(waypoint.userId)/\(mediaId)_thumb.jpg"
        
        // Upload original to storage
        _ = try await supabase.storage
            .from("waypoint-media")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // Upload thumbnail
        if let thumbnailData = thumbnailData {
            _ = try await supabase.storage
                .from("waypoint-thumbnails")
                .upload(
                    thumbnailPath,
                    data: thumbnailData,
                    options: FileOptions(contentType: "image/jpeg")
                )
        }
        
        // Create media record in database
        struct MediaInsert: Codable {
            let id: String
            let waypoint_id: String
            let user_id: String
            let file_path: String
            let storage_bucket: String
            let media_type: String
            let file_size_bytes: Int
            let mime_type: String
            let privacy_level: String
            let taken_at: String?
            let latitude: Double?
            let longitude: Double?
        }
        
        let mediaRecord = MediaInsert(
            id: mediaId.uuidString,
            waypoint_id: waypoint.id.uuidString,
            user_id: waypoint.userId.uuidString,
            file_path: fileName,
            storage_bucket: "waypoint-media",
            media_type: "photo",
            file_size_bytes: imageData.count,
            mime_type: "image/jpeg",
            privacy_level: privacyLevel,
            taken_at: metadata?.creationDate?.ISO8601Format(),
            latitude: metadata?.location?.coordinate.latitude,
            longitude: metadata?.location?.coordinate.longitude
        )
        
        try await supabase.client
            .from("media")
            .insert(mediaRecord)
            .execute()
        
        return mediaId
    }
    
    private func createThumbnail(from imageData: Data) async -> Data? {
        guard let uiImage = UIImage(data: imageData) else { return nil }
        
        let maxSize: CGFloat = 400
        let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height)
        let newSize = CGSize(
            width: uiImage.size.width * scale,
            height: uiImage.size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumbnail = renderer.image { context in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return thumbnail.jpegData(compressionQuality: 0.8)
    }
    
    private func extractPhotoMetadata(from item: PhotosPickerItem) async -> PhotoMetadata? {
        // This is a simplified version - in production you'd extract EXIF data
        return PhotoMetadata(
            creationDate: Date(),
            location: nil,
            cameraInfo: nil
        )
    }
}

struct PhotoMetadata {
    let creationDate: Date?
    let location: CLLocation?
    let cameraInfo: String?
}