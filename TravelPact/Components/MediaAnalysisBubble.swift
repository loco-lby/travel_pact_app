// MVP: Media features temporarily disabled for contact location focus
/*
import SwiftUI

struct MediaAnalysisBubble: View {
    @ObservedObject var analysisManager = BackgroundPhotoAnalysisManager.shared
    @State private var showReviewSheet = false
    @State private var isPressed = false
    var onWaypointsAdded: (() -> Void)? = nil
    
    private var progressValue: CGFloat {
        guard let progress = analysisManager.progress else { return 0 }
        return CGFloat(progress.current) / CGFloat(max(progress.total, 1))
    }
    
    private var badgeCount: Int {
        if analysisManager.hasCompletedAnalysis {
            return analysisManager.pendingWaypoints.count
        } else if let progress = analysisManager.progress {
            return progress.waypointsFound
        }
        return 0
    }
    
    private var shouldShow: Bool {
        // Always show the bubble for easy access to travel timeline
        return true
    }
    
    var body: some View {
        Group {
            if shouldShow {
                Button(action: {
                    showReviewSheet = true
                }) {
                    ZStack {
                        // Background circle with glass effect
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                        
                        // Progress ring
                        if analysisManager.isAnalyzing {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                .frame(width: 56, height: 56)
                            
                            Circle()
                                .trim(from: 0, to: progressValue)
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 56, height: 56)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.3), value: progressValue)
                        } else if analysisManager.hasCompletedAnalysis {
                            // Completion ring
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 56, height: 56)
                        }
                        
                        // Icon - changes based on state
                        Image(systemName: getIconName())
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(
                                getIconGradient()
                            )
                        
                        // Badge
                        if badgeCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(analysisManager.hasCompletedAnalysis ? Color.green : Color.purple)
                                    .frame(width: 22, height: 22)
                                
                                Text("\(badgeCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 20, y: -20)
                        }
                    }
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
                    isPressed = pressing
                }, perform: {})
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                .sheet(isPresented: $showReviewSheet, onDismiss: {
                    // Check if waypoints were added and trigger reload
                    if analysisManager.pendingWaypoints.isEmpty {
                        onWaypointsAdded?()
                    }
                }) {
                    WaypointReviewView()
                }
            }
        }
    }
    
    private func getIconName() -> String {
        if analysisManager.isAnalyzing {
            return "photo.stack"
        } else if analysisManager.hasCompletedAnalysis || !analysisManager.pendingWaypoints.isEmpty {
            return "photo.stack.fill"
        } else {
            return "clock.arrow.circlepath"
        }
    }
    
    private func getIconGradient() -> LinearGradient {
        if analysisManager.hasCompletedAnalysis || !analysisManager.pendingWaypoints.isEmpty {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        MediaAnalysisBubble()
    }
}
*/