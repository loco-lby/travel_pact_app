import SwiftUI
import MapKit

// Helper to create route path for Map
@MainActor
@MapContentBuilder
func createRoutePaths(waypoints: [Waypoint], animation: Double) -> some MapContent {
    let sortedWaypoints = waypoints.sorted { $0.sequenceOrder < $1.sequenceOrder }
    
    ForEach(0..<max(0, sortedWaypoints.count - 1), id: \.self) { index in
        if let startCoord = sortedWaypoints[index].coordinate,
           let endCoord = sortedWaypoints[index + 1].coordinate {
            MapPolyline(coordinates: [startCoord, endCoord])
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.7),
                            Color.purple.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: animation > 0 ? [] : [10, 5]
                    )
                )
        }
    }
}