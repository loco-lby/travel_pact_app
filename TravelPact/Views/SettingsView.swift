import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hideFromOthersMap = false
    @State private var showNotifications = true
    @State private var shareExactLocation = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showingSavedAlert = false
    @State private var showingCacheClearedAlert = false
    @State private var showingClearCacheConfirmation = false
    @State private var showingContactsManagement = false
    @State private var alertMessage = ""
    @State private var hasLoadedSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Privacy Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Privacy")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                // Hide from others' maps
                                SettingToggle(
                                    icon: "eye.slash.fill",
                                    title: "Hide from Others' Maps",
                                    subtitle: "Your contacts won't see you on their maps",
                                    isOn: $hideFromOthersMap
                                )
                                .onChange(of: hideFromOthersMap) { _, newValue in
                                    if hasLoadedSettings {
                                        saveSettings()
                                    }
                                }

                                Divider()
                                    .background(Color.white.opacity(0.1))

                                // Share exact location
                                SettingToggle(
                                    icon: "location.fill",
                                    title: "Share Exact Location",
                                    subtitle: "Share precise location with app users",
                                    isOn: $shareExactLocation
                                )
                                .onChange(of: shareExactLocation) { _, newValue in
                                    if hasLoadedSettings {
                                        saveSettings()
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }

                        // Notifications Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notifications")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                // Show notifications
                                SettingToggle(
                                    icon: "bell.fill",
                                    title: "Push Notifications",
                                    subtitle: "Get notified when contacts join or update location",
                                    isOn: $showNotifications
                                )
                                .onChange(of: showNotifications) { _, newValue in
                                    if hasLoadedSettings {
                                        saveSettings()
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }

                        // Account Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Account")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                // Manage Contacts
                                SettingRow(
                                    icon: "person.2.fill",
                                    title: "Manage Contacts",
                                    showChevron: true
                                ) {
                                    showingContactsManagement = true
                                }

                                Divider()
                                    .background(Color.white.opacity(0.1))

                                // Clear Cache
                                SettingRow(
                                    icon: "trash.fill",
                                    title: "Clear Cache",
                                    showChevron: false,
                                    tintColor: .orange
                                ) {
                                    showingClearCacheConfirmation = true
                                }
                            }
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Cache Cleared", isPresented: $showingCacheClearedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All cached data has been cleared successfully.")
        }
        .confirmationDialog("Clear Cache?", isPresented: $showingClearCacheConfirmation, titleVisibility: .visible) {
            Button("Clear Cache", role: .destructive) {
                clearCache()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete all cached contact locations and app data. You'll need to re-sync your contacts.")
        }
        .sheet(isPresented: $showingContactsManagement) {
            ContactsManagementView()
        }
    }

    private func loadSettings() {
        Task {
            do {
                let session = try await SupabaseManager.shared.auth.session
                let response = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("hide_from_others_map, share_exact_location, show_notifications")
                    .eq("id", value: session.user.id.uuidString)
                    .single()
                    .execute()

                if let data = try? JSONDecoder().decode(PrivacySettings.self, from: response.data) {
                    await MainActor.run {
                        hideFromOthersMap = data.hide_from_others_map ?? false
                        shareExactLocation = data.share_exact_location ?? false
                        showNotifications = data.show_notifications ?? true
                        isLoading = false
                        hasLoadedSettings = true
                    }
                }
            } catch {
                print("Error loading settings: \(error)")
                await MainActor.run {
                    isLoading = false
                    hasLoadedSettings = true
                }
            }
        }
    }

    private func saveSettings() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            do {
                let session = try await SupabaseManager.shared.auth.session
                let settings = PrivacySettings(
                    hide_from_others_map: hideFromOthersMap,
                    share_exact_location: shareExactLocation,
                    show_notifications: showNotifications
                )

                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(settings)
                    .eq("id", value: session.user.id.uuidString)
                    .execute()

                await MainActor.run {
                    isSaving = false
                    alertMessage = "Your privacy settings have been updated."
                    showingSavedAlert = true
                }
            } catch {
                print("Error saving settings: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }

    private func clearCache() {
        // Clear Core Data cache
        ContactLocationManager.shared.clearCache()

        // Clear any image caches
        URLCache.shared.removeAllCachedResponses()

        // Clear UserDefaults cache if any
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Show confirmation
        showingCacheClearedAlert = true
    }
}

struct PrivacySettings: Codable {
    let hide_from_others_map: Bool?
    let share_exact_location: Bool?
    let show_notifications: Bool?
}

struct SettingToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    var tintColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(tintColor.opacity(0.8))
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(tintColor)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}