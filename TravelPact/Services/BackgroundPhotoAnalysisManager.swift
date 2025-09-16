// MVP: Media features temporarily disabled for contact location focus
/*
import Foundation
import SwiftUI
import Photos
import CoreLocation
import UserNotifications

// MARK: - Background Photo Analysis Manager

@MainActor
class BackgroundPhotoAnalysisManager: ObservableObject {
    static let shared = BackgroundPhotoAnalysisManager()
    
    @Published var isAnalyzing = false
    @Published var progress: PhotoAnalysisProgress?
    @Published var hasCompletedAnalysis = false
    @Published var pendingWaypoints: [PhotoWaypoint] = []
    @Published var errorMessage: String?
    @Published var hasStartedAnalysisRecently = false // Track if we just started
    @Published var syncProgress: PhotoAnalysisProgress? // Track sync progress
    
    let photoService = PhotoAnalysisService()
    private var analysisTask: Task<Void, Never>?
    
    private init() {
        // Check if there are pending waypoints from a previous session
        loadPendingWaypoints()
        print("📸 BackgroundPhotoAnalysisManager initialized")
        print("📸 hasCompletedAnalysis: \(hasCompletedAnalysis)")
        print("📸 pendingWaypoints count: \(pendingWaypoints.count)")
        print("📸 isAnalyzing: \(isAnalyzing)")
        
        // Check if we need to resume analysis
        checkAndResumeAnalysis()
    }
    
    // MARK: - Public Methods
    
    func startBackgroundAnalysis(granularity: String = "city", forceRestart: Bool = false, selectedAssets: [PHAsset]? = nil) {
        guard !isAnalyzing else { 
            print("📸 Analysis already in progress")
            return 
        }
        
        // Check if we already completed analysis and have pending waypoints
        if !forceRestart && hasCompletedAnalysis && !pendingWaypoints.isEmpty {
            print("📸 Analysis already completed with \(pendingWaypoints.count) pending waypoints")
            return
        }
        
        print("📸 Starting background photo analysis with granularity: \(granularity)")
        isAnalyzing = true
        hasCompletedAnalysis = false
        hasStartedAnalysisRecently = true
        errorMessage = nil
        
        // Keep the recently started flag for a while
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            await MainActor.run {
                self.hasStartedAnalysisRecently = false
            }
        }
        
        // Request notification permission for completion
        requestNotificationPermission()
        
        // Start analysis in background
        // Mark that we've started analysis
        UserDefaults.standard.set(true, forKey: "HasStartedPhotoAnalysis")
        
        analysisTask = Task {
            do {
                try await photoService.analyzePhotoLibrary(
                    granularity: granularity,
                    resumeFromLastPosition: !forceRestart,
                    selectedAssets: selectedAssets
                )
                
                // Analysis completed successfully
                await MainActor.run {
                    self.pendingWaypoints = self.photoService.waypoints
                    self.isAnalyzing = false
                    self.hasCompletedAnalysis = true
                    print("📸 Analysis completed! Found \(self.pendingWaypoints.count) waypoints")
                    print("📸 isAnalyzing: \(self.isAnalyzing), hasCompletedAnalysis: \(self.hasCompletedAnalysis)")
                    self.savePendingWaypoints()
                    self.sendCompletionNotification()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
        
        // Set up progress monitoring
        Task { @MainActor in
            print("📸 Starting progress monitoring")
            for await _ in Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().values {
                if let serviceProgress = photoService.progress {
                    self.progress = serviceProgress
                    print("📸 Progress update: \(serviceProgress.current)/\(serviceProgress.total) photos, \(serviceProgress.waypointsFound) waypoints found")
                }
                
                // Check if we should stop monitoring
                if !self.isAnalyzing && !photoService.isAnalyzing && !photoService.isPaused {
                    print("📸 Stopping progress monitoring - analysis complete")
                    break
                }
            }
        }
    }
    
    func pauseAnalysis() {
        photoService.pauseAnalysis()
    }
    
    func resumeAnalysis() {
        Task {
            try? await photoService.resumeAnalysis()
        }
    }
    
    func cancelAnalysis() {
        analysisTask?.cancel()
        photoService.cancelAnalysis()
        isAnalyzing = false
        progress = nil
    }
    
    @MainActor
    func clearPendingWaypoints() {
        pendingWaypoints = []
        hasCompletedAnalysis = false
        progress = nil // Clear progress too
        UserDefaults.standard.removeObject(forKey: "PendingPhotoWaypoints")
        UserDefaults.standard.removeObject(forKey: "HasCompletedPhotoAnalysis")
        UserDefaults.standard.removeObject(forKey: "HasStartedPhotoAnalysis")
        UserDefaults.standard.removeObject(forKey: "PhotoAnalysisLastProcessedIndex")
    }
    
    func syncSelectedWaypoints(_ selectedIds: Set<UUID>) async throws {
        // Filter waypoints based on selection
        let waypointsToSync = pendingWaypoints.filter { selectedIds.contains($0.id) }
        
        guard !waypointsToSync.isEmpty else {
            print("❌ No waypoints to sync")
            throw PhotoAnalysisError.noWaypointsToSync
        }
        
        // Set the waypoints in photoService before syncing
        photoService.waypoints = waypointsToSync
        
        // Monitor sync progress
        let progressTask = Task { @MainActor in
            for await _ in Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().values {
                if let serviceProgress = photoService.progress {
                    self.syncProgress = serviceProgress
                }
                
                // Stop monitoring when sync is complete
                if self.syncProgress?.current == self.syncProgress?.total {
                    break
                }
            }
        }
        
        // Now sync to database
        try await photoService.syncToDatabase(selectedWaypointIds: selectedIds)
        
        // Cancel progress monitoring
        progressTask.cancel()
        
        // Clear pending waypoints after successful sync
        await MainActor.run {
            self.syncProgress = nil
            clearPendingWaypoints()
        }
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Permission requested
        }
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Photo Analysis Complete"
        content.body = "Found \(pendingWaypoints.count) locations from your photos. Tap to review."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "photo-analysis-complete",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func savePendingWaypoints() {
        // Save waypoints to UserDefaults for persistence
        if let encoded = try? JSONEncoder().encode(pendingWaypoints) {
            UserDefaults.standard.set(encoded, forKey: "PendingPhotoWaypoints")
            UserDefaults.standard.set(hasCompletedAnalysis, forKey: "HasCompletedPhotoAnalysis")
            UserDefaults.standard.synchronize() // Force immediate save
            print("📸 Saved \(pendingWaypoints.count) waypoints and hasCompletedAnalysis: \(hasCompletedAnalysis) to storage")
        }
    }
    
    private func loadPendingWaypoints() {
        hasCompletedAnalysis = UserDefaults.standard.bool(forKey: "HasCompletedPhotoAnalysis")
        print("📸 Loading saved state - hasCompletedAnalysis: \(hasCompletedAnalysis)")
        
        if let data = UserDefaults.standard.data(forKey: "PendingPhotoWaypoints"),
           let waypoints = try? JSONDecoder().decode([PhotoWaypoint].self, from: data) {
            pendingWaypoints = waypoints
            print("📸 Loaded \(waypoints.count) pending waypoints from storage")
        } else {
            print("📸 No pending waypoints found in storage")
        }
    }
    
    private func checkAndResumeAnalysis() {
        // Check if we have an incomplete analysis
        let lastProcessedIndex = UserDefaults.standard.integer(forKey: "PhotoAnalysisLastProcessedIndex")
        let hasStartedAnalysis = UserDefaults.standard.bool(forKey: "HasStartedPhotoAnalysis")
        
        print("📸 Checking for incomplete analysis - lastProcessedIndex: \(lastProcessedIndex), hasStartedAnalysis: \(hasStartedAnalysis)")
        
        // If we started analysis but didn't complete it, and we don't have pending waypoints, resume
        if hasStartedAnalysis && !hasCompletedAnalysis && pendingWaypoints.isEmpty {
            print("📸 Resuming incomplete analysis from index \(lastProcessedIndex)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startBackgroundAnalysis()
            }
        }
    }
    
    func hasIncompleteAnalysis() -> Bool {
        let lastProcessedIndex = UserDefaults.standard.integer(forKey: "PhotoAnalysisLastProcessedIndex")
        let hasStartedAnalysis = UserDefaults.standard.bool(forKey: "HasStartedPhotoAnalysis")
        return hasStartedAnalysis && !hasCompletedAnalysis && lastProcessedIndex > 0
    }
}
*/