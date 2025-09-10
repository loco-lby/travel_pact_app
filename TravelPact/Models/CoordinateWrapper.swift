import CoreLocation

// Wrapper to make CLLocationCoordinate2D Equatable for SwiftUI state
struct CoordinateWrapper: Equatable {
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: CoordinateWrapper, rhs: CoordinateWrapper) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}