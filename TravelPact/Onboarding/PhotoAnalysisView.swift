// MVP: Media features temporarily disabled for contact location focus
/*
import SwiftUI
import Photos

struct PhotoAnalysisView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @ObservedObject var analysisManager = BackgroundPhotoAnalysisManager.shared
    @State private var showPermissionAlert = false
    @State private var granularityLevel = "city"
    @State private var hasStartedAnalysis = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.02, green: 0.02, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Header
                VStack(spacing: 20) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Analyze Your Travel History")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("We'll scan your photo library in the background to automatically create waypoints from your past travels")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                // Granularity selector (only shown if not started)
                if !hasStartedAnalysis && !analysisManager.isAnalyzing {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Location Detail Level")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                ForEach(["precise", "area_code"], id: \.self) { level in
                                    Button(action: {
                                        granularityLevel = level
                                    }) {
                                        Text(level == "area_code" ? "Area Code" : level.capitalized)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(granularityLevel == level ? .black : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(granularityLevel == level ? Color.white : Color.white.opacity(0.2))
                                            )
                                    }
                                }
                            }
                            
                            HStack(spacing: 10) {
                                ForEach(["city", "country"], id: \.self) { level in
                                    Button(action: {
                                        granularityLevel = level
                                    }) {
                                        Text(level.capitalized)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(granularityLevel == level ? .black : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(granularityLevel == level ? Color.white : Color.white.opacity(0.2))
                                            )
                                    }
                                }
                            }
                        }
                        
                        Text(granularityDescription)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Status indicator
                if hasStartedAnalysis || analysisManager.isAnalyzing {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            Text("Analysis started in background")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Text("You can continue using the app while we analyze your photos")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        if let progress = analysisManager.progress {
                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(progress.current)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue)
                                    Text("Processed")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                VStack {
                                    Text("\(progress.waypointsFound)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.green)
                                    Text("Locations")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if !hasStartedAnalysis && !analysisManager.isAnalyzing {
                        Button(action: {
                            Task {
                                await startAnalysis()
                            }
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Start Background Analysis")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text(hasStartedAnalysis || analysisManager.isAnalyzing ? "Continue" : "Skip for now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 40)
            }
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
    }
    
    private var granularityDescription: String {
        switch granularityLevel {
        case "precise":
            return "Groups photos by exact location"
        case "area_code":
            return "Groups photos by postal/ZIP code area"
        case "city":
            return "Groups photos by city (e.g., Paris, Tokyo)"
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
        
        // Start background analysis
        await MainActor.run {
            withAnimation {
                hasStartedAnalysis = true
            }
            analysisManager.startBackgroundAnalysis(granularity: granularityLevel)
        }
        
        // Don't auto-navigate - let user click Continue button when ready
    }
    
    private func completeOnboarding() {
        onboardingViewModel.completeOnboarding()
    }
}
*/