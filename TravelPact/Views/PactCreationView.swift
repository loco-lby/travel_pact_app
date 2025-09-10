import SwiftUI
import MapKit

// MARK: - Pact Creation View
struct PactCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pactService = PactService.shared
    @StateObject private var contactService = ContactSyncService.shared
    
    @State private var pactName = ""
    @State private var pactDescription = ""
    @State private var selectedPactType: PactType = .timeline
    @State private var selectedContacts: Set<UUID> = []
    @State private var selectedRoute: UUID?
    @State private var startDate = Date()
    @State private var endDate: Date?
    @State private var showingContactPicker = false
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var selectedContactsList: [TravelPactContact] {
        contactService.contacts.filter { selectedContacts.contains($0.id) }
    }
    
    var isValid: Bool {
        !pactName.isEmpty && !selectedContacts.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Pact Type Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pact Type")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 12) {
                                ForEach(PactType.allCases, id: \.self) { type in
                                    PactTypeCard(
                                        type: type,
                                        isSelected: selectedPactType == type,
                                        action: { selectedPactType = type }
                                    )
                                }
                            }
                        }
                        
                        // Pact Details
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Pact Details")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                TextField("Enter pact name", text: $pactName)
                                    .textFieldStyle(GlassTextFieldStyle())
                            }
                            
                            // Description Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description (Optional)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                TextField("Describe your pact", text: $pactDescription, axis: .vertical)
                                    .lineLimit(3...6)
                                    .textFieldStyle(GlassTextFieldStyle())
                            }
                            
                            // Date Selection (for Live Pacts)
                            if selectedPactType == .live {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Duration")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .tint(.blue)
                                        .foregroundColor(.white)
                                    
                                    if endDate != nil {
                                        DatePicker("End", selection: Binding($endDate)!, displayedComponents: [.date, .hourAndMinute])
                                            .datePickerStyle(.compact)
                                            .tint(.blue)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Toggle("Set end date", isOn: Binding(
                                        get: { endDate != nil },
                                        set: { enabled in
                                            endDate = enabled ? Calendar.current.date(byAdding: .day, value: 7, to: startDate) : nil
                                        }
                                    ))
                                    .tint(.blue)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Invited Contacts
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Invite Contacts")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                                
                                Button(action: { showingContactPicker = true }) {
                                    Label("Add", systemImage: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if selectedContactsList.isEmpty {
                                HStack {
                                    Image(systemName: "person.2.slash")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    Text("No contacts selected")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial.opacity(0.3))
                                )
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(selectedContactsList) { contact in
                                        SelectedContactRow(
                                            contact: contact,
                                            onRemove: {
                                                selectedContacts.remove(contact.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                
                // Loading Overlay
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Creating pact...")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
            }
            .navigationTitle("Create Pact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createPact()
                    }
                    .foregroundColor(isValid ? .blue : .white.opacity(0.3))
                    .disabled(!isValid || isCreating)
                }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView(selectedContacts: $selectedContacts)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createPact() {
        isCreating = true
        
        Task {
            do {
                let _ = try await pactService.createPact(
                    name: pactName,
                    description: pactDescription.isEmpty ? nil : pactDescription,
                    type: selectedPactType,
                    routeId: selectedRoute,
                    startDate: startDate,
                    endDate: endDate,
                    invitedContacts: selectedContactsList
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Pact Type Card
struct PactTypeCard: View {
    let type: PactType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                VStack(spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    
                    Text(type.description)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.blue : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
    }
}

// MARK: - Selected Contact Row
struct SelectedContactRow: View {
    let contact: TravelPactContact
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Contact bubble
            if contact.hasAccount {
                if let photoURL = contact.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ContactInitialsBubble(
                            initials: contact.bubbleInitials,
                            hasAccount: true
                        )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    ContactInitialsBubble(
                        initials: contact.bubbleInitials,
                        hasAccount: true
                    )
                    .frame(width: 36, height: 36)
                }
            } else {
                ContactInitialsBubble(
                    initials: contact.bubbleInitials,
                    hasAccount: false
                )
                .frame(width: 36, height: 36)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if !contact.hasAccount {
                    Text("Will receive SMS invite")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
}

// MARK: - Contact Picker View
struct ContactPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var contactService = ContactSyncService.shared
    @Binding var selectedContacts: Set<UUID>
    @State private var searchText = ""
    
    var filteredContacts: [TravelPactContact] {
        if searchText.isEmpty {
            return contactService.contacts
        }
        return contactService.contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredContacts) { contact in
                    ContactPickerRow(
                        contact: contact,
                        isSelected: selectedContacts.contains(contact.id),
                        onToggle: {
                            if selectedContacts.contains(contact.id) {
                                selectedContacts.remove(contact.id)
                            } else {
                                selectedContacts.insert(contact.id)
                            }
                        }
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Select Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Contact Picker Row
struct ContactPickerRow: View {
    let contact: TravelPactContact
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)
                
                // Contact info
                if contact.hasAccount {
                    if let photoURL = contact.photoURL {
                        AsyncImage(url: URL(string: photoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        ContactInitialsBubble(
                            initials: contact.bubbleInitials,
                            hasAccount: true
                        )
                        .frame(width: 40, height: 40)
                    }
                } else {
                    ContactInitialsBubble(
                        initials: contact.bubbleInitials,
                        hasAccount: false
                    )
                    .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if contact.hasAccount {
                        Label("TravelPact User", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    } else if contact.phoneNumber != nil {
                        Label("SMS Invite", systemImage: "message")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// GlassTextFieldStyle is already defined in WaypointEditView.swift