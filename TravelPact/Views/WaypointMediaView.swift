import SwiftUI
import PhotosUI
import Supabase

struct MediaItem: Identifiable, Codable {
    let id: UUID
    let waypointId: UUID
    let userId: UUID
    let filePath: String
    let storageBucket: String?
    let mediaType: String
    let fileSizeBytes: Int64?
    let mimeType: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Double?
    let privacyLevel: String
    let caption: String?
    let takenAt: Date?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case waypointId = "waypoint_id"
        case userId = "user_id"
        case filePath = "file_path"
        case storageBucket = "storage_bucket"
        case mediaType = "media_type"
        case fileSizeBytes = "file_size_bytes"
        case mimeType = "mime_type"
        case width
        case height
        case durationSeconds = "duration_seconds"
        case privacyLevel = "privacy_level"
        case caption
        case takenAt = "taken_at"
        case latitude
        case longitude
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WaypointMediaView: View {
    let waypoint: Waypoint
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoading = true
    @State private var selectedItems: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showSortingInterface = false
    @State private var sortingSession: UUID?
    @State private var showSlideshow = false
    @State private var errorMessage: String?
    
    @StateObject private var uploadService = MediaUploadService.shared
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading media...")
                        .foregroundColor(.white)
                } else if mediaItems.isEmpty {
                    EmptyMediaView(onAddPhotos: { showPhotosPicker = true })
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(mediaItems) { item in
                                MediaTileView(
                                    item: item,
                                    isSelected: selectedItems.contains(item.id),
                                    isSelectionMode: isSelectionMode
                                )
                                .aspectRatio(1, contentMode: .fit)
                                .onTapGesture {
                                    if isSelectionMode {
                                        toggleSelection(item.id)
                                    } else {
                                        // Show full screen media viewer
                                        viewMedia(item)
                                    }
                                }
                                .onLongPressGesture {
                                    if !isSelectionMode {
                                        isSelectionMode = true
                                        selectedItems.insert(item.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                    }
                }
                
                // Upload progress overlay
                if uploadService.isUploading {
                    UploadProgressView(
                        progress: uploadService.uploadProgress,
                        currentTask: uploadService.currentUploadTask
                    )
                }
                
                // Floating Add Photos button - always visible
                if !isLoading && !uploadService.isUploading {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showPhotosPicker = true }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle(waypoint.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Add Photos button - always visible
                        Button(action: { showPhotosPicker = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        // Menu for other options
                        Menu {
                            Button(action: { showSortingInterface = true }) {
                                Label("Sort Photos", systemImage: "square.grid.3x3.square")
                            }
                            
                            if !mediaItems.filter({ $0.privacyLevel == "public_slideshow" }).isEmpty {
                                Button(action: { showSlideshow = true }) {
                                    Label("View Slideshow", systemImage: "play.rectangle")
                                }
                            }
                            
                            if isSelectionMode {
                                Button(action: { 
                                    isSelectionMode = false
                                    selectedItems.removeAll()
                                }) {
                                    Label("Cancel Selection", systemImage: "xmark.circle")
                                }
                            } else {
                                Button(action: { isSelectionMode = true }) {
                                    Label("Select Photos", systemImage: "checkmark.circle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 50,
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: selectedPhotos) { _, newValue in
                if !newValue.isEmpty {
                    uploadPhotos(newValue)
                }
            }
            .alert("Upload Complete", isPresented: .constant(!uploadService.uploadErrors.isEmpty)) {
                Button("OK") {
                    uploadService.uploadErrors.removeAll()
                }
            } message: {
                Text(uploadService.uploadErrors.joined(separator: "\n"))
            }
            .sheet(isPresented: $showSortingInterface) {
                MediaSortingView(
                    waypoint: waypoint,
                    mediaItems: $mediaItems,
                    sortingSession: $sortingSession
                )
            }
            .fullScreenCover(isPresented: $showSlideshow) {
                SlideshowView(
                    mediaItems: mediaItems.filter { $0.privacyLevel == "public_slideshow" }
                )
            }
        }
        .onAppear {
            loadMedia()
        }
    }
    
    private func loadMedia() {
        Task {
            do {
                let response = try await SupabaseManager.shared.client
                    .from("media")
                    .select()
                    .eq("waypoint_id", value: waypoint.id.uuidString)
                    .neq("privacy_level", value: "trash")
                    .order("taken_at", ascending: false)
                    .execute()
                
                let decoder = JSONDecoder()
                // Use custom date decoding for Supabase timestamps
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Try ISO8601 with fractional seconds first
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    
                    // Try without fractional seconds
                    formatter.formatOptions = [.withInternetDateTime]
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                    
                    // Try custom format used by Supabase
                    let customFormatter = DateFormatter()
                    customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = customFormatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                mediaItems = try decoder.decode([MediaItem].self, from: response.data)
                print("📸 Loaded \(mediaItems.count) media items")
                isLoading = false
            } catch {
                print("Error loading media: \(error)")
                errorMessage = "Failed to load media"
                isLoading = false
            }
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
        
        if selectedItems.isEmpty {
            isSelectionMode = false
        }
    }
    
    private func viewMedia(_ item: MediaItem) {
        // TODO: Implement full screen media viewer
    }
    
    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        Task {
            await uploadService.uploadPhotosToWaypoint(items, waypoint: waypoint)
            selectedPhotos.removeAll()
            // Reload media after upload with a small delay to ensure database is updated
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            loadMedia()
            
            // Also reload media counts for the waypoint marker
            await MediaService.shared.loadMediaCount(for: waypoint.id)
            await MediaService.shared.loadThumbnail(for: waypoint.id)
        }
    }
}

struct MediaTileView: View {
    let item: MediaItem
    let isSelected: Bool
    let isSelectionMode: Bool
    @StateObject private var mediaService = MediaService.shared
    @State private var thumbnailURL: URL?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Thumbnail image
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: item.mediaType == "video" ? "video.slash" : "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Video indicator
                if item.mediaType == "video" {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.caption)
                            if let duration = item.durationSeconds {
                                Text(formatDuration(duration))
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                    }
                }
                
                // Selection indicator
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .blue : .white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Privacy indicator
                if item.privacyLevel == "public_slideshow" {
                    VStack {
                        HStack {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.green.opacity(0.8)))
                                .padding(4)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
        }
        .task {
            thumbnailURL = await mediaService.getThumbnailURL(for: item)
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct EmptyMediaView: View {
    let onAddPhotos: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No photos yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Add photos to this waypoint to create your travel story")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onAddPhotos) {
                Label("Add Photos", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
        }
    }
}

struct UploadProgressView: View {
    let progress: Double
    let currentTask: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Uploading Photos")
                .font(.headline)
                .foregroundColor(.white)
            
            if !currentTask.isEmpty {
                Text(currentTask)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 200)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Placeholder for sorting view - will be implemented next
struct MediaSortingView: View {
    let waypoint: Waypoint
    @Binding var mediaItems: [MediaItem]
    @Binding var sortingSession: UUID?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Media Sorting Interface - Coming Soon")
                .navigationTitle("Sort Media")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// Placeholder for slideshow view
struct SlideshowView: View {
    let mediaItems: [MediaItem]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Text("Slideshow - \(mediaItems.count) photos")
                .foregroundColor(.white)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}