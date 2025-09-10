import SwiftUI
import CoreLocation

// MARK: - Contact Carousel
struct ContactCarousel: View {
    @StateObject private var contactService = ContactSyncService.shared
    @StateObject private var locationManager = ContactLocationManager.shared
    @State private var showFullGrid = false
    @State private var selectedContact: TravelPactContact?
    @State private var showLocationSearch = false
    @State private var contactForLocationAssignment: TravelPactContact?
    @Binding var showContactGlobe: Bool
    @Binding var contactForGlobe: TravelPactContact?
    @Binding var contactLocationToNavigate: CoordinateWrapper?
    @Binding var showAddConnection: Bool
    
    private let maxVisibleContacts = 6
    
    var visibleContacts: [TravelPactContact] {
        Array(contactService.contacts.prefix(maxVisibleContacts))
    }
    
    var remainingCount: Int {
        max(0, contactService.contacts.count - maxVisibleContacts)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Location search bar (appears above contacts when active)
            if let contact = contactForLocationAssignment, showLocationSearch {
                ContactLocationSearchView(
                    contact: contact,
                    isPresented: Binding(
                        get: { showLocationSearch },
                        set: { newValue in
                            showLocationSearch = newValue
                            if !newValue {
                                // Clear the contact assignment when closing
                                contactForLocationAssignment = nil
                            }
                        }
                    ),
                    onLocationAssigned: { coordinate in
                        // Navigate to the newly assigned location
                        contactLocationToNavigate = CoordinateWrapper(coordinate: coordinate)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Contact carousel
            VStack(spacing: 0) {
                if !contactService.contacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Add contact button at the beginning
                            AddContactBubble {
                                showAddConnection = true
                            }
                            
                            // Contact bubbles
                            ForEach(visibleContacts) { contact in
                                ContactBubble(contact: contact) {
                                    handleContactTap(contact)
                                }
                            }
                            
                            // "More" button if there are additional contacts
                            if remainingCount > 0 {
                                MoreContactsBubble(count: remainingCount) {
                                    showFullGrid = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 80)
                } else if contactService.isLoading {
                    LoadingContactCarousel()
                } else {
                    EmptyContactCarousel {
                        Task {
                            if await contactService.requestContactsPermission() {
                                await contactService.syncContacts()
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLocationSearch)
        .sheet(isPresented: $showFullGrid) {
            ContactGridView(
                contacts: contactService.contacts,
                onContactSelected: { contact in
                    showFullGrid = false
                    handleContactTap(contact)
                }
            )
        }
        .task {
            // Auto-sync contacts on appear if we have permission
            if contactService.hasPermission && contactService.contacts.isEmpty {
                await contactService.syncContacts()
            }
        }
    }
    
    private func handleContactTap(_ contact: TravelPactContact) {
        selectedContact = contact
        
        if contact.hasAccount {
            // Open their globe view
            contactForGlobe = contact
            showContactGlobe = true
        } else if let contactId = contact.contactIdentifier,
                  let locationData = locationManager.getLocation(for: contactId) {
            // Navigate to their assigned location on the map
            contactLocationToNavigate = CoordinateWrapper(coordinate: locationData.coordinate)
        } else {
            // Show location assignment popup for non-user contacts without location
            contactForLocationAssignment = contact
            showLocationSearch = true
        }
    }
}

// MARK: - Contact Bubble
struct ContactBubble: View {
    let contact: TravelPactContact
    let action: () -> Void
    @StateObject private var locationManager = ContactLocationManager.shared
    
    private var hasAssignedLocation: Bool {
        guard let contactId = contact.contactIdentifier else { return false }
        return locationManager.getLocation(for: contactId) != nil
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if let photoURL = contact.photoURL, contact.hasAccount {
                    // TravelPact user with photo
                    AsyncImage(url: URL(string: photoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.blue, Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                        case .empty, .failure:
                            ContactInitialsBubble(
                                initials: contact.bubbleInitials,
                                hasAccount: contact.hasAccount,
                                hasLocation: hasAssignedLocation
                            )
                        @unknown default:
                            ContactInitialsBubble(
                                initials: contact.bubbleInitials,
                                hasAccount: contact.hasAccount,
                                hasLocation: hasAssignedLocation
                            )
                        }
                    }
                } else {
                    // Contact without photo or non-app user
                    ContactInitialsBubble(
                        initials: contact.bubbleInitials,
                        hasAccount: contact.hasAccount,
                        hasLocation: hasAssignedLocation
                    )
                }
                
                // Online indicator for TravelPact users OR location indicator for non-users
                if contact.hasAccount {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 22, y: -22)
                } else if hasAssignedLocation {
                    // Location indicator for non-app contacts
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 22, y: -22)
                }
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Contact Initials Bubble
struct ContactInitialsBubble: View {
    let initials: String
    let hasAccount: Bool
    var hasLocation: Bool = false
    
    var bubbleGradient: LinearGradient {
        if hasAccount {
            // Purple gradient for TravelPact users
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Clear/glass for non-app contacts
            return LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var borderColors: [Color] {
        if hasAccount {
            // Blue/cyan for TravelPact users
            return [Color.blue.opacity(0.8), Color.cyan.opacity(0.4)]
        } else if hasLocation {
            // Green for non-app contacts with assigned location
            return [Color.green.opacity(0.8), Color.green.opacity(0.4)]
        } else {
            // Default white for non-app contacts without location
            return [Color.white.opacity(0.5), Color.white.opacity(0.1)]
        }
    }
    
    var borderWidth: CGFloat {
        if hasAccount || hasLocation {
            return 2
        } else {
            return 1
        }
    }
    
    var textColor: Color {
        hasAccount ? .white : .white
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(bubbleGradient)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: borderColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: borderWidth
                        )
                )
            
            Text(initials.uppercased())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
    }
}

// MARK: - More Contacts Bubble
struct MoreContactsBubble: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 64, height: 64)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Text("+\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Add Contact Bubble
struct AddContactBubble: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 64, height: 64)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Loading State
struct LoadingContactCarousel: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 80)
    }
}

// MARK: - Empty State
struct EmptyContactCarousel: View {
    let onSyncContacts: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onSyncContacts) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Sync Contacts")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            Text("Connect with friends who use TravelPact")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(height: 80)
    }
}

// MARK: - Contact Grid View
struct ContactGridView: View {
    let contacts: [TravelPactContact]
    let onContactSelected: (TravelPactContact) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Glass background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .background(
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                    )
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(contacts) { contact in
                            ContactGridItem(contact: contact) {
                                onContactSelected(contact)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Contact Grid Item
struct ContactGridItem: View {
    let contact: TravelPactContact
    let action: () -> Void
    @StateObject private var locationManager = ContactLocationManager.shared
    
    private var hasAssignedLocation: Bool {
        guard let contactId = contact.contactIdentifier else { return false }
        return locationManager.getLocation(for: contactId) != nil
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    if let photoURL = contact.photoURL, contact.hasAccount {
                        AsyncImage(url: URL(string: photoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.blue, Color.cyan],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                            case .empty, .failure:
                                ContactInitialsBubble(
                                    initials: contact.bubbleInitials,
                                    hasAccount: contact.hasAccount,
                                    hasLocation: hasAssignedLocation
                                )
                                .frame(width: 80, height: 80)
                            @unknown default:
                                ContactInitialsBubble(
                                    initials: contact.bubbleInitials,
                                    hasAccount: contact.hasAccount,
                                    hasLocation: hasAssignedLocation
                                )
                                .frame(width: 80, height: 80)
                            }
                        }
                    } else {
                        ContactInitialsBubble(
                            initials: contact.bubbleInitials,
                            hasAccount: contact.hasAccount,
                            hasLocation: hasAssignedLocation
                        )
                        .frame(width: 80, height: 80)
                    }
                    
                    // Status indicator
                    if contact.hasAccount {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 28, y: -28)
                    } else if hasAssignedLocation {
                        // Location indicator for non-app contacts
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 28, y: -28)
                    }
                }
                
                VStack(spacing: 4) {
                    Text(contact.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(contact.hasAccount ? "On TravelPact" : hasAssignedLocation ? "Location set" : "Invite to TravelPact")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(contact.hasAccount ? .green : hasAssignedLocation ? .green : .orange)
                }
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}