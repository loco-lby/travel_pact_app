// MVP: WaypointReviewView temporarily disabled (photo analysis feature)
/*
import SwiftUI
import MapKit
import CoreLocation
import Photos

struct WaypointReviewView: View {
    @Environment(\.dismiss) var dismiss
    // MVP: Photo analysis manager temporarily disabled
    // @ObservedObject var analysisManager = BackgroundPhotoAnalysisManager.shared
    @State private var selectedWaypoints: Set<UUID> = []
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .chronological
    @State private var expandedWaypoints: Set<UUID> = []
    @State private var showPhotoSelection = false
    
    enum SortOrder: String, CaseIterable {
        case chronological = "Date"
        case alphabetical = "Name"
        case photoCount = "Photos"
        case country = "Country"
    }
    
    private var sortedWaypoints: [PhotoWaypoint] {
        // MVP: Return empty array since photo analysis is disabled
        let waypoints: [PhotoWaypoint] = [] // analysisManager.pendingWaypoints
        
        // Filter by search
        let filtered = searchText.isEmpty ? waypoints : waypoints.filter { waypoint in
            waypoint.locationName.localizedCaseInsensitiveContains(searchText) ||
            (waypoint.city?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (waypoint.country?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        // Sort
        switch sortOrder {
        case .chronological:
            return filtered.sorted { $0.startDate < $1.startDate }
        case .alphabetical:
            return filtered.sorted { $0.locationName < $1.locationName }
        case .photoCount:
            return filtered.sorted { $0.photoCount > $1.photoCount }
        case .country:
            return filtered.sorted { 
                let country1 = $0.country ?? ""
                let country2 = $1.country ?? ""
                if country1 == country2 {
                    return $0.startDate < $1.startDate
                }
                return country1 < country2
            }
        }
    }
    
    // Group waypoints by month/year for chronological view
    private var groupedWaypoints: [(key: String, waypoints: [PhotoWaypoint])] {
        if sortOrder != .chronological {
            return [("", sortedWaypoints)]
        }
        
        let grouped = Dictionary(grouping: sortedWaypoints) { waypoint in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: waypoint.startDate)
        }
        
        return grouped.sorted { first, second in
            // Sort by date
            if let firstWaypoint = first.value.first,
               let secondWaypoint = second.value.first {
                return firstWaypoint.startDate < secondWaypoint.startDate
            }
            return false
        }.map { (key: $0.key, waypoints: $0.value) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.02, green: 0.02, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MVP: Progress indicator temporarily disabled
                    /*
                    if analysisManager.isAnalyzing, let progress = analysisManager.progress {
                        AnalysisProgressBar(progress: progress)
                            .padding()
                            .background(.ultraThinMaterial)
                    }
                    */
                    
                    // MVP: Always show empty state since photo analysis is disabled
                    // if analysisManager.pendingWaypoints.isEmpty && !analysisManager.isAnalyzing {
                    if true {
                        Spacer()
                        EmptyWaypointView(
                            hasIncompleteAnalysis: false, // analysisManager.hasIncompleteAnalysis(),
                            onStartAnalysis: {
                                showPhotoSelection = true
                            }
                        )
                        Spacer()
                    } else if false { // !analysisManager.pendingWaypoints.isEmpty
                    // Header with stats
                    VStack(spacing: 16) {
                        // Stats bar
                        HStack(spacing: 30) {
                            StatCard(
                                value: "0", // "\(analysisManager.pendingWaypoints.count)"
                                label: "Total Locations",
                                icon: "mappin.circle.fill",
                                color: .blue
                            )
                            
                            StatCard(
                                value: "\(selectedWaypoints.count)",
                                label: "Selected",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            let totalPhotos = 0 // analysisManager.pendingWaypoints.reduce(0) { $0 + $1.photoCount }
                            StatCard(
                                value: "\(totalPhotos)",
                                label: "Total Photos",
                                icon: "photo.stack",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                        
                        // Search and sort
                        HStack(spacing: 12) {
                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white.opacity(0.5))
                                TextField("Search locations...", text: $searchText)
                                    .foregroundColor(.white)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            
                            // Sort picker
                            Menu {
                                ForEach(SortOrder.allCases, id: \.self) { order in
                                    Button(action: {
                                        withAnimation {
                                            sortOrder = order
                                        }
                                    }) {
                                        HStack {
                                            Text(order.rawValue)
                                            if sortOrder == order {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(sortOrder.rawValue)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Select all/none buttons
                        HStack {
                            Button(action: selectAll) {
                                Text("Select All")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.3))
                            
                            Button(action: selectNone) {
                                Text("Select None")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color.black.opacity(0.3))
                    
                    // Waypoint list
                    ScrollView {
                        LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                            ForEach(groupedWaypoints, id: \.key) { group in
                                Section {
                                    ForEach(group.waypoints) { waypoint in
                                        WaypointReviewRow(
                                            waypoint: waypoint,
                                            isSelected: selectedWaypoints.contains(waypoint.id),
                                            isExpanded: expandedWaypoints.contains(waypoint.id),
                                            onToggleSelection: {
                                                toggleSelection(for: waypoint.id)
                                            },
                                            onToggleExpansion: {
                                                toggleExpansion(for: waypoint.id)
                                            }
                                        )
                                    }
                                } header: {
                                    if !group.key.isEmpty {
                                        HStack {
                                            Text(group.key)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.7))
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(
                                            LinearGradient(
                                                colors: [
                                                    Color.black.opacity(0.8),
                                                    Color.black.opacity(0.6)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for bottom buttons
                    }
                    
                    }
                    
                    // Bottom action buttons - always visible
                    VStack(spacing: 12) {
                        // Add more photos button
                        HStack(spacing: 12) {
                            Button(action: {
                                showPhotoSelection = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text("Add Photos")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.purple.opacity(0.15))
                                .cornerRadius(12)
                            }
                            
                            // MVP: Analysis controls temporarily disabled
                            /*
                            if !analysisManager.pendingWaypoints.isEmpty {
                                Button(action: {
                                    analysisManager.startBackgroundAnalysis(forceRestart: true)
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Analyze All")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(12)
                                }
                            }
                            */
                        }
                        
                        // MVP: Save controls temporarily disabled  
                        /*
                        if !analysisManager.pendingWaypoints.isEmpty {
                            Button(action: saveSelected) {
                            HStack {
                                if !isSyncing {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(selectedWaypoints.isEmpty ? "Skip" : "Add \(selectedWaypoints.count) to Map")
                                } else {
                                    Text("Adding to Map...")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                selectedWaypoints.isEmpty ? Color.gray : Color.white
                            )
                            .cornerRadius(14)
                            }
                            .disabled(isSyncing)
                        }
                        */
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Done")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.9),
                                Color.black.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
            .overlay(
                // MVP: Sync progress overlay temporarily disabled
                /*
                Group {
                    if isSyncing, let syncProgress = analysisManager.syncProgress {
                        SyncProgressOverlay(progress: syncProgress)
                    }
                }
                */
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Travel Timeline")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        // MVP: Photo selection sheet temporarily disabled
        /*
        .sheet(isPresented: $showPhotoSelection) {
            PhotoSelectionView { selectedAssets in
                if selectedAssets.isEmpty {
                    // Analyze all
                    analysisManager.startBackgroundAnalysis()
                } else {
                    // Analyze selected
                    analysisManager.startBackgroundAnalysis(selectedAssets: selectedAssets)
                }
            }
        }
        */
        .alert("Error", isPresented: .constant(syncError != nil)) {
            Button("OK") {
                syncError = nil
            }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
        .onAppear {
            // MVP: Auto-select disabled since no waypoints
            // selectedWaypoints = Set(analysisManager.pendingWaypoints.map { $0.id })
        }
    }
    
    // MARK: - Actions
    
    private func selectAll() {
        withAnimation {
            selectedWaypoints = Set(sortedWaypoints.map { $0.id })
        }
    }
    
    private func selectNone() {
        withAnimation {
            selectedWaypoints.removeAll()
        }
    }
    
    private func toggleSelection(for id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedWaypoints.contains(id) {
                selectedWaypoints.remove(id)
            } else {
                selectedWaypoints.insert(id)
            }
        }
    }
    
    private func toggleExpansion(for id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedWaypoints.contains(id) {
                expandedWaypoints.remove(id)
            } else {
                expandedWaypoints.insert(id)
            }
        }
    }
    
    private func saveSelected() {
        guard !selectedWaypoints.isEmpty else {
            // Just dismiss if nothing selected
            analysisManager.clearPendingWaypoints()
            dismiss()
            return
        }
        
        isSyncing = true
        
        Task {
            do {
                try await analysisManager.syncSelectedWaypoints(selectedWaypoints)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }
}

// MARK: - Stat Card Component

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Waypoint Review Row

private struct WaypointReviewRow: View {
    let waypoint: PhotoWaypoint
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleSelection: () -> Void
    let onToggleExpansion: () -> Void
    
    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let start = formatter.string(from: waypoint.startDate)
        
        if Calendar.current.isDate(waypoint.startDate, inSameDayAs: waypoint.endDate) {
            return start
        }
        
        let end = formatter.string(from: waypoint.endDate)
        
        // Check if same year
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let startYear = yearFormatter.string(from: waypoint.startDate)
        let endYear = yearFormatter.string(from: waypoint.endDate)
        
        if startYear != endYear {
            return "\(start), \(startYear) - \(end), \(endYear)"
        }
        
        return "\(start) - \(end), \(startYear)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggleSelection) {
                HStack(spacing: 12) {
                    // Selection checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .green : .white.opacity(0.3))
                    
                    // Location info
                    VStack(alignment: .leading, spacing: 6) {
                        // Location name
                        Text(waypoint.locationName.components(separatedBy: " (").first ?? waypoint.locationName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // Details row
                        HStack(spacing: 12) {
                            // Date
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                Text(dateRange)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            
                            // Photo count
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                Text("\(waypoint.photoCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            
                            // Location details
                            if let country = waypoint.country {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 11))
                                    Text(country)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Expand button
                    Button(action: onToggleExpansion) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? Color.green.opacity(0.3) : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Map preview
                    Map(coordinateRegion: .constant(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: waypoint.location.latitude,
                                longitude: waypoint.location.longitude
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    ), annotationItems: [waypoint]) { _ in
                        MapPin(coordinate: waypoint.location, tint: .red)
                    }
                    .frame(height: 150)
                    .cornerRadius(8)
                    .disabled(true)
                    
                    // Additional details
                    VStack(alignment: .leading, spacing: 6) {
                        if let city = waypoint.city {
                            DetailRow(label: "City", value: city)
                        }
                        if let areaCode = waypoint.areaCode {
                            DetailRow(label: "Area Code", value: areaCode)
                        }
                        DetailRow(label: "Coordinates", value: String(format: "%.3f, %.3f", waypoint.location.latitude, waypoint.location.longitude))
                        DetailRow(label: "Granularity", value: waypoint.granularityLevel.capitalized)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.top, -8)
                .padding(.horizontal, 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Analysis Progress Bar

private struct AnalysisProgressBar: View {
    let progress: PhotoAnalysisProgress
    
    private var progressValue: CGFloat {
        CGFloat(progress.current) / CGFloat(max(progress.total, 1))
    }
    
    private var progressPercentage: String {
        let percentage = Int(progressValue * 100)
        return "\(percentage)%"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Status text
            HStack {
                Text(progress.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(progressPercentage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressValue, height: 8)
                        .animation(.linear(duration: 0.3), value: progressValue)
                }
            }
            .frame(height: 8)
            
            // Stats
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                    Text("\(progress.current)/\(progress.total)")
                        .font(.system(size: 12))
                }
                
                if progress.waypointsFound > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text("\(progress.waypointsFound) locations")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.green)
                }
                
                if progress.photosSkipped > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                        Text("\(progress.photosSkipped) skipped")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.orange)
                }
                
                Spacer()
            }
            .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Empty Waypoint View

private struct EmptyWaypointView: View {
    let hasIncompleteAnalysis: Bool
    let onStartAnalysis: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: hasIncompleteAnalysis ? "photo.stack.fill" : "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title
            Text(hasIncompleteAnalysis ? "Resume Photo Analysis" : "No Travel Timeline Yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text(hasIncompleteAnalysis ? 
                 "Your photo analysis was interrupted. Tap below to continue analyzing your photos." :
                 "Start analyzing your photo library to automatically generate your travel timeline.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Start button
            Button(action: onStartAnalysis) {
                HStack {
                    Image(systemName: hasIncompleteAnalysis ? "play.fill" : "sparkles")
                    Text(hasIncompleteAnalysis ? "Resume Analysis" : "Start Photo Analysis")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(14)
                .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Sync Progress Overlay

private struct SyncProgressOverlay: View {
    let progress: PhotoAnalysisProgress
    
    private var progressValue: CGFloat {
        CGFloat(progress.current) / CGFloat(max(progress.total, 1))
    }
    
    private var progressPercentage: String {
        let percentage = Int(progressValue * 100)
        return "\(percentage)%"
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            // Progress card
            VStack(spacing: 24) {
                // Icon with animation
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progressValue)
                    
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Title
                Text("Adding to Map")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Progress details
                VStack(spacing: 12) {
                    // Current location being synced
                    if let location = progress.currentLocation {
                        Text(location)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Progress text
                    HStack(spacing: 8) {
                        Text("\(progress.current)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                        Text("of")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(progress.total)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("waypoints")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Percentage
                    Text(progressPercentage)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progressValue, height: 12)
                            .animation(.linear(duration: 0.3), value: progressValue)
                    }
                }
                .frame(height: 12)
                
                // Estimated time (optional)
                if progress.current > 0 && progress.current < progress.total {
                    let remaining = progress.total - progress.current
                    let avgTimePerItem = 2.0 // Estimate 2 seconds per waypoint
                    let estimatedSeconds = Double(remaining) * avgTimePerItem
                    let minutes = Int(estimatedSeconds / 60)
                    let seconds = Int(estimatedSeconds.truncatingRemainder(dividingBy: 60))
                    
                    Text(minutes > 0 ? "About \(minutes)m \(seconds)s remaining" : "About \(seconds)s remaining")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 40)
        }
    }
}
*/