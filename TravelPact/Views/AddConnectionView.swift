import SwiftUI
import CoreLocation

struct AddConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var connectionsManager: ConnectionsManager
    @State private var connectionName = ""
    @State private var searchQuery = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var notes = ""
    @State private var isSearching = false
    @State private var searchResults: [UserProfile] = []
    @State private var showLocationPicker = false
    @State private var isAdding = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .white.opacity(0.3), radius: 10)
                            
                            Text("Add Connection")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Add friends to see on your map")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Search for App Users
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search TravelPact Users")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white.opacity(0.5))
                                
                                TextField("Search by name...", text: $searchQuery)
                                    .foregroundColor(.white)
                                    .onSubmit {
                                        searchUsers()
                                    }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                            
                            if isSearching {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Searching...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding()
                            }
                            
                            // Search Results
                            ForEach(searchResults, id: \.id) { user in
                                Button(action: {
                                    addAppUserConnection(user)
                                }) {
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.purple)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(user.name)
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                            
                                            if let location = user.location {
                                                Text(location.address ?? "Location set")
                                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.05))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 24)
                        
                        // Add Non-App User
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add Someone Not on TravelPact")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            
                            // Name Field
                            LiquidGlassTextField(
                                placeholder: "Friend's Name",
                                text: $connectionName
                            )
                            
                            // Location Button
                            Button(action: { showLocationPicker = true }) {
                                HStack {
                                    Image(systemName: "location")
                                        .font(.system(size: 20))
                                    
                                    if locationName.isEmpty {
                                        Text("Set Their Location")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                    } else {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Location Set")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                            Text(locationName)
                                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.ultraThinMaterial)
                                        )
                                )
                            }
                            
                            // Notes Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (optional)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                TextField("Add notes...", text: $notes, axis: .vertical)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(.ultraThinMaterial)
                                            )
                                    )
                                    .lineLimit(3...5)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        // Add Button
                        Button(action: addNonAppConnection) {
                            HStack {
                                if isAdding {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Add Connection")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                        .padding(.horizontal, 24)
                        .disabled(connectionName.isEmpty || isAdding)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationSearchView { coordinate, name in
                selectedLocation = coordinate
                locationName = name
            }
        }
    }
    
    private func searchUsers() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        errorMessage = ""
        
        Task {
            do {
                searchResults = try await connectionsManager.searchAppUsers(query: searchQuery)
                isSearching = false
            } catch {
                await MainActor.run {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }
    
    private func addAppUserConnection(_ user: UserProfile) {
        isAdding = true
        errorMessage = ""
        
        Task {
            do {
                try await connectionsManager.connectWithAppUser(
                    userId: user.id,
                    userName: user.name
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    if error.localizedDescription.contains("already exists") {
                        errorMessage = "You're already connected with \(user.name)"
                    } else {
                        errorMessage = "Failed to add connection: \(error.localizedDescription)"
                    }
                    isAdding = false
                }
            }
        }
    }
    
    private func addNonAppConnection() {
        guard !connectionName.isEmpty else { return }
        
        isAdding = true
        errorMessage = ""
        
        Task {
            do {
                try await connectionsManager.addConnection(
                    name: connectionName,
                    location: selectedLocation,
                    locationName: locationName.isEmpty ? nil : locationName,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add connection: \(error.localizedDescription)"
                    isAdding = false
                }
            }
        }
    }
}