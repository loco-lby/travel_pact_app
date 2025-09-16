import SwiftUI
import MapKit

struct SpinningGlobeBackground: View {
    @State private var rotation: Double = 0
    @State private var mapStyle = MapStyle.imagery(elevation: .realistic)
    let spinSpeed: Double // Rotation duration in seconds
    
    private var normalizedLongitude: Double {
        // Keep longitude within -180 to 180 range
        let modRotation = rotation.truncatingRemainder(dividingBy: 360)
        if modRotation > 180 {
            return modRotation - 360
        } else if modRotation < -180 {
            return modRotation + 360
        }
        return modRotation
    }
    
    var body: some View {
        GeometryReader { geometry in
            Map(
                coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 20, longitude: normalizedLongitude),
                    span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
                ))
            )
            .mapStyle(mapStyle)
            .disabled(true)
            .ignoresSafeArea()
            .onAppear {
                // Animate rotation continuously
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    rotation += (360.0 / spinSpeed) * 0.05
                }
            }
        }
    }
}

// MVP: OnboardingGlobeBackground temporarily disabled due to PhotoWaypoint dependency
/*
struct OnboardingGlobeBackground: View {
    let showWaypoints: Bool
    let waypoints: [PhotoWaypoint]
    @State private var rotation: Double = 0
    @State private var mapStyle = MapStyle.imagery(elevation: .realistic)
    
    var body: some View {
        Map(
            coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
            )),
            annotationItems: showWaypoints ? waypoints : []
        ) { waypoint in
            MapAnnotation(coordinate: CLLocationCoordinate2D(
                latitude: waypoint.location.latitude,
                longitude: waypoint.location.longitude
            )) {
                WaypointPulse()
            }
        }
        .mapStyle(mapStyle)
        .disabled(true)
        .ignoresSafeArea()
    }
}
*/