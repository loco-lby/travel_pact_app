import SwiftUI
import Photos

struct PhotoAnalysisView: View {
    @StateObject private var photoService = PhotoAnalysisService()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var showPermissionAlert = false
    @State private var skipConfirmation = false
    @State private var granularityLevel = "city"
    @State private var isSyncing = false
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Build Your Travel Timeline")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("We'll analyze your photos to create waypoints from your past travels")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if photoService.isAnalyzing {
                    // Progress View
                    VStack(spacing: 24) {
                        ProgressView(value: Double(photoService.progress?.current ?? 0),
                                   total: Double(photoService.progress?.total ?? 100))
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .padding(.horizontal, 40)
                        
                        VStack(spacing: 8) {
                            if let progress = photoService.progress {
                                Text(progress.message)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                if let location = progress.currentLocation {
                                    Text("Current: \(location)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Text("\(progress.current) of \(progress.total)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        Button(action: {
                            photoService.cancelAnalysis()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(20)
                        }
                    }
                } else if !photoService.waypoints.isEmpty {
                    // Results View
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Analysis Complete!")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 4) {
                                Text("Found \(photoService.waypoints.count) locations")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                let totalPhotos = photoService.waypoints.reduce(0) { $0 + $1.photoCount }
                                Text("\(totalPhotos) photos organized")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if photoService.excludedPhotosCount > 0 {
                                    Text("\(photoService.excludedPhotosCount) photos without location excluded")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                            }
                        }
                        
                        // Waypoint Preview
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photoService.waypoints.prefix(5), id: \.id) { waypoint in
                                    VStack(spacing: 4) {
                                        Text(waypoint.locationName.components(separatedBy: " (").first ?? "")
                                            .font(.system(size: 14, weight: .medium))
                                            .lineLimit(1)
                                        Text("\(waypoint.photoCount) photos")
                                            .font(.system(size: 12))
                                            .opacity(0.7)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                                }
                                
                                if photoService.waypoints.count > 5 {
                                    Text("+\(photoService.waypoints.count - 5) more")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: {
                            Task {
                                await MainActor.run {
                                    isSyncing = true
                                }
                                
                                do {
                                    try await syncAndComplete()
                                } catch {
                                    print("❌ Error syncing and completing: \(error)")
                                    // Still complete onboarding even if sync fails
                                    await MainActor.run {
                                        isSyncing = false
                                        completeOnboarding()
                                    }
                                }
                            }
                        }) {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Save & Continue")
                                }
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                        }
                        .disabled(isSyncing)
                        .padding(.horizontal, 40)
                        
                        // Skip button if syncing or if user wants to skip
                        Button(action: {
                            completeOnboarding()
                        }) {
                            Text(isSyncing ? "Skip sync" : "Continue without saving")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                } else {
                    // Initial Setup View
                    VStack(spacing: 24) {
                        // Granularity Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Detail Level")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack(spacing: 12) {
                                ForEach(["city", "region", "country"], id: \.self) { level in
                                    Button(action: {
                                        granularityLevel = level
                                    }) {
                                        Text(level.capitalized)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(granularityLevel == level ? .black : .white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(
                                                granularityLevel == level ? Color.white : Color.white.opacity(0.2)
                                            )
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            
                            Text(granularityDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await startAnalysis()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Analyze Photo Library")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                skipConfirmation = true
                            }) {
                                Text("Skip for now")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .alert("Photo Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant photo library access in Settings to analyze your travel photos.")
        }
        .alert("Skip Photo Analysis?", isPresented: $skipConfirmation) {
            Button("Skip", role: .destructive) {
                completeOnboarding()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can always analyze your photos later from the settings menu.")
        }
        .alert("Error", isPresented: .constant(photoService.errorMessage != nil)) {
            Button("OK") {
                photoService.errorMessage = nil
            }
        } message: {
            if let error = photoService.errorMessage {
                Text(error)
            }
        }
    }
    
    private var granularityDescription: String {
        switch granularityLevel {
        case "city":
            return "Groups photos by city (e.g., Paris, Tokyo)"
        case "region":
            return "Groups photos by state/region (e.g., California, Bavaria)"
        case "country":
            return "Groups photos by country (e.g., France, Japan)"
        default:
            return ""
        }
    }
    
    private func startAnalysis() async {
        // Check permission first
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus != .authorized {
                await MainActor.run {
                    showPermissionAlert = true
                }
                return
            }
        } else if status != .authorized {
            await MainActor.run {
                showPermissionAlert = true
            }
            return
        }
        
        // Start analysis
        do {
            try await photoService.analyzePhotoLibrary(granularity: granularityLevel)
        } catch {
            print("Analysis error: \(error)")
        }
    }
    
    private func syncAndComplete() async throws {
        try await photoService.syncToDatabase()
        await MainActor.run {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        onboardingViewModel.completeOnboarding()
    }
}

struct PhotoAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoAnalysisView()
            .environmentObject(OnboardingViewModel())
    }
}