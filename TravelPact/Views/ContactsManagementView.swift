import SwiftUI
import CoreLocation

struct ContactsManagementView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var contactService = ContactSyncService.shared
    @StateObject private var locationManager = ContactLocationManager.shared
    @State private var showLocationSearch = false
    @State private var contactForLocationAssignment: TravelPactContact?
    @State private var selectedContacts: Set<String> = []
    @State private var showBulkLocationAssignment = false
    @State private var searchText = ""
    
    private var filteredContacts: [TravelPactContact] {
        if searchText.isEmpty {
            return contactService.contacts
        } else {
            return contactService.contacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var contactsWithLocations: [TravelPactContact] {
        filteredContacts.filter { contact in
            guard let contactId = contact.contactIdentifier else { return false }
            return locationManager.getLocation(for: contactId) != nil
        }
    }
    
    private var contactsWithoutLocations: [TravelPactContact] {
        filteredContacts.filter { contact in
            guard let contactId = contact.contactIdentifier else { return true }
            return locationManager.getLocation(for: contactId) == nil
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Glass background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .background(
                        AnimatedGradientBackground()
                            .ignoresSafeArea()
                    )
                
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                    
                    // Bulk actions bar
                    if !selectedContacts.isEmpty {
                        bulkActionsBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Contact list
                    contactsList
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedContacts.isEmpty)
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            if await contactService.requestContactsPermission() {
                                await contactService.syncContacts()
                            }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showLocationSearch) {
            if let contact = contactForLocationAssignment {
                ContactLocationSearchView(
                    contact: contact,
                    isPresented: Binding(
                        get: { showLocationSearch },
                        set: { newValue in
                            showLocationSearch = newValue
                            if !newValue {
                                contactForLocationAssignment = nil
                            }
                        }
                    )
                )
            }
        }
        .sheet(isPresented: $showBulkLocationAssignment) {
            BulkLocationAssignmentView(
                contacts: selectedContacts.compactMap { contactId in
                    contactService.contacts.first { $0.contactIdentifier == contactId }
                },
                isPresented: $showBulkLocationAssignment,
                onComplete: {
                    selectedContacts.removeAll()
                }
            )
        }
        .task {
            if contactService.hasPermission && contactService.contacts.isEmpty {
                await contactService.syncContacts()
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 16))
            
            TextField("Search contacts...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 16))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var bulkActionsBar: some View {
        HStack {
            Text("\(selectedContacts.count) selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Button("Clear") {
                selectedContacts.removeAll()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            
            Button("Assign Location") {
                showBulkLocationAssignment = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.7))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }
    
    private var contactsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Contacts with locations
                if !contactsWithLocations.isEmpty {
                    sectionHeader(title: "With Locations", count: contactsWithLocations.count)
                    ForEach(contactsWithLocations) { contact in
                        ContactManagementRow(
                            contact: contact,
                            isSelected: selectedContacts.contains(contact.contactIdentifier ?? ""),
                            onTap: {
                                handleContactTap(contact)
                            },
                            onSelectionChanged: { isSelected in
                                if let contactId = contact.contactIdentifier {
                                    if isSelected {
                                        selectedContacts.insert(contactId)
                                    } else {
                                        selectedContacts.remove(contactId)
                                    }
                                }
                            }
                        )
                    }
                }
                
                // Contacts without locations
                if !contactsWithoutLocations.isEmpty {
                    sectionHeader(title: "Need Locations", count: contactsWithoutLocations.count)
                    ForEach(contactsWithoutLocations) { contact in
                        ContactManagementRow(
                            contact: contact,
                            isSelected: selectedContacts.contains(contact.contactIdentifier ?? ""),
                            onTap: {
                                handleContactTap(contact)
                            },
                            onSelectionChanged: { isSelected in
                                if let contactId = contact.contactIdentifier {
                                    if isSelected {
                                        selectedContacts.insert(contactId)
                                    } else {
                                        selectedContacts.remove(contactId)
                                    }
                                }
                            }
                        )
                    }
                }
                
                // Empty state
                if filteredContacts.isEmpty && !contactService.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(searchText.isEmpty ? "No contacts synced yet" : "No contacts match your search")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if searchText.isEmpty {
                            Button("Sync Contacts") {
                                Task {
                                    if await contactService.requestContactsPermission() {
                                        await contactService.syncContacts()
                                    }
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                    }
                    .padding(.vertical, 60)
                }
            }
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
        .refreshable {
            await contactService.syncContacts()
        }
    }
    
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("(\(count))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
    }
    
    private func handleContactTap(_ contact: TravelPactContact) {
        contactForLocationAssignment = contact
        showLocationSearch = true
    }
}

// MARK: - Contact Management Row
struct ContactManagementRow: View {
    let contact: TravelPactContact
    let isSelected: Bool
    let onTap: () -> Void
    let onSelectionChanged: (Bool) -> Void
    @StateObject private var locationManager = ContactLocationManager.shared
    
    private var hasAssignedLocation: Bool {
        guard let contactId = contact.contactIdentifier else { return false }
        return locationManager.getLocation(for: contactId) != nil
    }
    
    private var locationName: String? {
        guard let contactId = contact.contactIdentifier else { return nil }
        return locationManager.getLocation(for: contactId)?.locationName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.blue : Color.white.opacity(0.4), lineWidth: 1.5)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Contact info
            HStack(spacing: 12) {
                // Contact avatar/initials
                ContactInitialsBubble(
                    initials: contact.bubbleInitials,
                    hasAccount: contact.hasAccount,
                    hasLocation: hasAssignedLocation
                )
                .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if contact.hasAccount {
                            Text("On TravelPact")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        } else if hasAssignedLocation {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text(locationName ?? "Location set")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("Tap to set location")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Action indicator
                Image(systemName: hasAssignedLocation ? "location.fill" : "location")
                    .font(.system(size: 14))
                    .foregroundColor(hasAssignedLocation ? .green : .white.opacity(0.4))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isSelected ? 0.05 : 0.02))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

// AnimatedGradientBackground is already defined in LiquidGlass.swift