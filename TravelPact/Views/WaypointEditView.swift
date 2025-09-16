import SwiftUI
import CoreLocation

struct WaypointEditView: View {
    let waypoint: Waypoint
    let onSave: (Waypoint) -> Void
    
    @State private var waypointName: String = ""
    @State private var notes: String = ""
    @Environment(\.dismiss) private var dismiss
    
    init(waypoint: Waypoint, onSave: @escaping (Waypoint) -> Void) {
        self.waypoint = waypoint
        self.onSave = onSave
        _waypointName = State(initialValue: waypoint.name)
        _notes = State(initialValue: waypoint.notes ?? "")
    }
    
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        
        if let arrival = waypoint.arrivalTime, let departure = waypoint.departureTime {
            if Calendar.current.isDate(arrival, inSameDayAs: departure) {
                return formatter.string(from: arrival)
            } else {
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = Calendar.current.component(.year, from: arrival) == Calendar.current.component(.year, from: departure) ? "MMM d" : "MMM d, yyyy"
                return "\(formatter.string(from: arrival)) - \(endFormatter.string(from: departure))"
            }
        }
        return ""
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with map preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.3),
                                            Color.cyan.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 150)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text(dateRangeText)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Edit fields
                        VStack(alignment: .leading, spacing: 20) {
                            // Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bookmark Name")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                TextField("Enter bookmark name", text: $waypointName)
                                    .textFieldStyle(GlassTextFieldStyle())
                            }
                            
                            // Location info (read-only)
                            if let city = waypoint.city {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Location")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Text([waypoint.areaCode, city, waypoint.country]
                                            .compactMap { $0 }
                                            .joined(separator: ", "))
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                    )
                                }
                            }
                            
                            // Notes field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (Optional)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                TextEditor(text: $notes)
                                    .scrollContentBackground(.hidden)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .frame(minHeight: 80)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Edit Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveChanges() {
        // Create updated bookmark with new name and notes
        // Since Waypoint is a struct with let properties, we need to create a new instance
        
        // Create a new bookmark with updated values
        let updated = Waypoint(
            id: waypoint.id,
            routeId: waypoint.routeId,
            userId: waypoint.userId,
            name: waypointName,
            knownLocation: waypoint.knownLocation,
            actualLocation: waypoint.actualLocation,
            granularityLevel: waypoint.granularityLevel,
            sequenceOrder: waypoint.sequenceOrder,
            arrivalTime: waypoint.arrivalTime,
            departureTime: waypoint.departureTime,
            city: waypoint.city,
            areaCode: waypoint.areaCode,
            country: waypoint.country,
            notes: notes.isEmpty ? nil : notes,
            createdAt: waypoint.createdAt,
            updatedAt: Date()
        )
        
        onSave(updated)
        dismiss()
    }
}

// Glass text field style
struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .accentColor(.blue)
    }
}