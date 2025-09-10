import SwiftUI
import CoreLocation

// MARK: - Contact Location Marker
struct ContactLocationMarker: View {
    let contact: TravelPactContact
    let locationData: ContactLocationData
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Outer ring with subtle pulse
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 36, height: 36)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.3 : 0.6)
                .animation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Main marker
            ZStack {
                // Background circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
                    )
                
                // Contact initials
                Text(contact.bubbleInitials.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Location pin indicator at bottom
            Image(systemName: "mappin")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.orange)
                .offset(y: 14)
        }
        .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Contact Location Info Popup
struct ContactLocationInfoCard: View {
    let contact: TravelPactContact
    let locationData: ContactLocationData
    let onClose: () -> Void
    let onUpdate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Contact initial bubble
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                    
                    Text(contact.bubbleInitials.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Not on TravelPact")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Location info
            VStack(alignment: .leading, spacing: 8) {
                Label(locationData.locationName, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                if let city = locationData.city {
                    Label(city, systemImage: "building.2")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let country = locationData.country {
                    Label(country, systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onUpdate) {
                    Label("Update Location", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                Button(action: {
                    // Invite to TravelPact
                    // TODO: Implement invite functionality
                }) {
                    Label("Invite", systemImage: "paperplane.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}