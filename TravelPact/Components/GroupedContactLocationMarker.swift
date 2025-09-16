import SwiftUI
import CoreLocation

// MARK: - Grouped Contact Location Marker
struct GroupedContactLocationMarker: View {
    let contactGroup: ContactLocationGroup
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            if contactGroup.count == 1 {
                // Single contact - use regular marker
                ContactLocationMarker(
                    contact: contactGroup.contacts.first!,
                    locationData: contactGroup.locationData
                )
            } else {
                // Multiple contacts - use grouped marker
                groupedMarker
            }
        }
    }
    
    private var groupedMarker: some View {
        ZStack {
            // Outer ring with subtle pulse
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.5), Color.orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 50, height: 50)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .opacity(isAnimating ? 0.3 : 0.7)
                .animation(
                    .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Main grouped marker background
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Count display
                VStack(spacing: 1) {
                    Text("\(contactGroup.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Location pin indicator at bottom
            Image(systemName: "mappin")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .offset(y: 21)
        }
        .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 3)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Grouped Contact Info Card
struct GroupedContactInfoCard: View {
    let contactGroup: ContactLocationGroup
    let onClose: () -> Void
    let onContactSelected: ((TravelPactContact) -> Void)?
    @State private var showAllContacts = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                // Location indicator
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contactGroup.locationData.locationName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(contactGroup.count) contacts here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Contact list preview or full list
            VStack(alignment: .leading, spacing: 8) {
                let displayedContacts = showAllContacts ? contactGroup.contacts : Array(contactGroup.contacts.prefix(3))
                
                ForEach(displayedContacts) { contact in
                    contactRow(contact)
                        .onTapGesture {
                            onContactSelected?(contact)
                        }
                }
                
                // Show more/less button
                if contactGroup.count > 3 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAllContacts.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showAllContacts ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                            Text(showAllContacts ? "Show Less" : "Show \(contactGroup.count - 3) More")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.orange.opacity(0.8))
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    // TODO: Bulk contact actions
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 14))
                        Text("Change Location")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Message all contacts
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 14))
                        Text("Message All")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func contactRow(_ contact: TravelPactContact) -> some View {
        HStack(spacing: 10) {
            // Contact initial
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(contact.bubbleInitials)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(contact.hasAccount ? "On TravelPact" : "Contact")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(contact.hasAccount ? .green : .orange.opacity(0.7))
            }
            
            Spacer()
            
            if contact.hasAccount {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}