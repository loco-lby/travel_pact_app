// MVP: Media features temporarily disabled for contact location focus
/*
import SwiftUI

struct PhotoAnalysisProgressBar: View {
    @ObservedObject var analysisManager = BackgroundPhotoAnalysisManager.shared
    @State private var isExpanded = false
    @State private var showReviewSheet = false
    
    var body: some View {
        let _ = print("📊 ProgressBar Check - isAnalyzing: \(analysisManager.isAnalyzing), hasCompleted: \(analysisManager.hasCompletedAnalysis), pendingCount: \(analysisManager.pendingWaypoints.count), hasStartedRecently: \(analysisManager.hasStartedAnalysisRecently)")
        
        let shouldShow = analysisManager.isAnalyzing || 
                        analysisManager.hasCompletedAnalysis || 
                        !analysisManager.pendingWaypoints.isEmpty ||
                        analysisManager.hasStartedAnalysisRecently
        
        let _ = print("📊 ProgressBar shouldShow: \(shouldShow)")
        
        Group {
            // Show progress bar if analyzing OR if there are pending waypoints to review OR if we just started
            if shouldShow {
                let _ = print("📊 ProgressBar RENDERING NOW")
                VStack(spacing: 0) {
                    // Compact progress bar
                    HStack(spacing: 12) {
                        // Progress indicator or completion icon
                        if analysisManager.hasCompletedAnalysis {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                                    .frame(width: 24, height: 24)
                                
                                Circle()
                                    .trim(from: 0, to: progressValue)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 24, height: 24)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.3), value: progressValue)
                            }
                        }
                        
                        // Status text
                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if let progress = analysisManager.progress, !analysisManager.hasCompletedAnalysis {
                                Text("\(progress.current) of \(progress.total) photos • \(progress.waypointsFound) locations")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                            } else if analysisManager.hasCompletedAnalysis {
                                Text("\(analysisManager.pendingWaypoints.count) locations ready to review")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 8) {
                            if analysisManager.hasCompletedAnalysis {
                                Button(action: {
                                    showReviewSheet = true
                                }) {
                                    Text("Review")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .cornerRadius(14)
                                }
                                
                                Button(action: {
                                    withAnimation {
                                        analysisManager.clearPendingWaypoints()
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            } else {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.9),
                                Color.black.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Expanded controls
                    if isExpanded && !analysisManager.hasCompletedAnalysis {
                        VStack(spacing: 12) {
                            // Detailed progress
                            if let progress = analysisManager.progress {
                                VStack(spacing: 8) {
                                    // Progress bar
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
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
                                        StatView(
                                            value: "\(progress.waypointsFound)",
                                            label: "Locations",
                                            color: .green
                                        )
                                        
                                        if progress.photosSkipped > 0 {
                                            StatView(
                                                value: "\(progress.photosSkipped)",
                                                label: "Skipped",
                                                color: .orange
                                            )
                                        }
                                        
                                        Spacer()
                                        
                                        // Control buttons
                                        HStack(spacing: 8) {
                                            Button(action: {
                                                analysisManager.pauseAnalysis()
                                            }) {
                                                Image(systemName: "pause.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(Color.orange.opacity(0.3))
                                                    .clipShape(Circle())
                                            }
                                            
                                            Button(action: {
                                                withAnimation {
                                                    analysisManager.cancelAnalysis()
                                                }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(Color.red.opacity(0.3))
                                                    .clipShape(Circle())
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }
                        .background(Color.black.opacity(0.85))
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 16))
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                .padding(.horizontal, isExpanded ? 0 : 12)
                .padding(.top, isExpanded ? 0 : 8) // Small padding from top
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            WaypointReviewView()
        }
    }
    
    private var progressValue: CGFloat {
        guard let progress = analysisManager.progress else { return 0 }
        return CGFloat(progress.current) / CGFloat(max(progress.total, 1))
    }
    
    private var statusTitle: String {
        if analysisManager.hasCompletedAnalysis {
            return "Photo Analysis Complete"
        } else if analysisManager.photoService.isPaused {
            return "Analysis Paused"
        } else {
            return "Analyzing Photos..."
        }
    }
}

// MARK: - Stat View Component

private struct StatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
*/