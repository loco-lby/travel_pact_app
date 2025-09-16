// MVP: Media features temporarily disabled for contact location focus
/*
import SwiftUI
import Photos

struct PhotoSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var allPhotos: [PHAsset] = []
    @State private var selectedPhotos: Set<PHAsset> = []
    @State private var isLoadingPhotos = true
    @State private var showOnlyWithLocation = true
    @State private var groupByMonth = true
    
    let onSelection: ([PHAsset]) -> Void
    
    private var filteredPhotos: [PHAsset] {
        if showOnlyWithLocation {
            return allPhotos.filter { $0.location != nil }
        }
        return allPhotos
    }
    
    private var groupedPhotos: [(key: String, photos: [PHAsset])] {
        if !groupByMonth {
            return [("All Photos", filteredPhotos)]
        }
        
        let grouped = Dictionary(grouping: filteredPhotos) { photo in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: photo.creationDate ?? Date())
        }
        
        return grouped.sorted { first, second in
            if let firstPhoto = first.value.first?.creationDate,
               let secondPhoto = second.value.first?.creationDate {
                return firstPhoto > secondPhoto
            }
            return false
        }.map { (key: $0.key, photos: $0.value.sorted { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.02, green: 0.02, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoadingPhotos {
                    ProgressView("Loading photos...")
                        .foregroundColor(.white)
                } else {
                    VStack(spacing: 0) {
                        // Header controls
                        HStack(spacing: 16) {
                            Toggle("Location Only", isOn: $showOnlyWithLocation)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Toggle("Group by Month", isOn: $groupByMonth)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        
                        // Photo count
                        HStack {
                            Text("\(filteredPhotos.count) photos")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(selectedPhotos.count) selected")
                                .foregroundColor(.purple)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Photo grid
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(groupedPhotos, id: \.key) { group in
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Section header
                                        HStack {
                                            Text(group.key)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                let groupAssets = Set(group.photos)
                                                if selectedPhotos.intersection(groupAssets).count == groupAssets.count {
                                                    selectedPhotos.subtract(groupAssets)
                                                } else {
                                                    selectedPhotos.formUnion(groupAssets)
                                                }
                                            }) {
                                                Text(selectedPhotos.intersection(Set(group.photos)).count == group.photos.count ? "Deselect All" : "Select All")
                                                    .font(.caption)
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                        .padding(.horizontal)
                                        
                                        // Photo grid
                                        LazyVGrid(columns: [
                                            GridItem(.adaptive(minimum: 80), spacing: 4)
                                        ], spacing: 4) {
                                            ForEach(group.photos, id: \.localIdentifier) { photo in
                                                PhotoThumbnail(
                                                    asset: photo,
                                                    isSelected: selectedPhotos.contains(photo),
                                                    hasLocation: photo.location != nil
                                                ) {
                                                    if selectedPhotos.contains(photo) {
                                                        selectedPhotos.remove(photo)
                                                    } else {
                                                        selectedPhotos.insert(photo)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        // Bottom actions
                        HStack(spacing: 16) {
                            Button(action: {
                                selectedPhotos = Set(filteredPhotos)
                            }) {
                                Text("Select All")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                onSelection(Array(selectedPhotos))
                                dismiss()
                            }) {
                                Text("Analyze \(selectedPhotos.count) Photos")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: selectedPhotos.isEmpty ? [.gray] : [.purple, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(selectedPhotos.isEmpty)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Analyze All") {
                        onSelection([])
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
        }
        .task {
            await loadPhotos()
        }
    }
    
    private func loadPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else { return }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        await MainActor.run {
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var photos: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                photos.append(asset)
            }
            self.allPhotos = photos
            self.isLoadingPhotos = false
        }
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    let isSelected: Bool
    let hasLocation: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 3)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
            }
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.purple)
                    .background(Circle().fill(.white))
                    .padding(4)
            }
            
            // Location indicator
            if hasLocation {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .offset(x: -4, y: 4)
            }
        }
        .onTapGesture {
            onTap()
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = false
        option.deliveryMode = .fastFormat
        
        await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 160, height: 160),
                contentMode: .aspectFill,
                options: option
            ) { image, _ in
                if let image = image {
                    Task { @MainActor in
                        self.thumbnail = image
                    }
                }
                continuation.resume()
            }
        }
    }
}
*/