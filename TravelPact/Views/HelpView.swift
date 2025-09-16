import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Getting Started
                        HelpSection(
                            title: "Getting Started",
                            icon: "flag.fill",
                            items: [
                                HelpItem(
                                    question: "How do I add a contact?",
                                    answer: "Tap the + button in the contact carousel at the bottom of the globe view. You can sync from your phone contacts or add manually."
                                ),
                                HelpItem(
                                    question: "How do I assign a location to a contact?",
                                    answer: "Tap on a contact without a location. Search for their city or select from popular locations."
                                ),
                                HelpItem(
                                    question: "What are waypoints?",
                                    answer: "Waypoints are your travel bookmarks - places you've been or plan to visit. Tap the location button to add your current location as a waypoint."
                                )
                            ],
                            isExpanded: expandedSection == "getting_started"
                        ) {
                            expandedSection = expandedSection == "getting_started" ? nil : "getting_started"
                        }

                        // Using the Globe
                        HelpSection(
                            title: "Using the Globe",
                            icon: "globe.americas.fill",
                            items: [
                                HelpItem(
                                    question: "How do I navigate the globe?",
                                    answer: "Swipe to rotate the globe. Pinch to zoom in and out. Tap on markers to see details."
                                ),
                                HelpItem(
                                    question: "What do the different markers mean?",
                                    answer: "Blue markers are app users, orange markers are contacts without the app, and purple markers are your waypoints."
                                ),
                                HelpItem(
                                    question: "How do I find a specific contact?",
                                    answer: "Tap on their bubble in the contact carousel and the globe will fly to their location."
                                )
                            ],
                            isExpanded: expandedSection == "globe"
                        ) {
                            expandedSection = expandedSection == "globe" ? nil : "globe"
                        }

                        // Privacy & Security
                        HelpSection(
                            title: "Privacy & Security",
                            icon: "lock.shield.fill",
                            items: [
                                HelpItem(
                                    question: "Who can see my location?",
                                    answer: "Only contacts you've added can see your location. You can hide from everyone in Settings."
                                ),
                                HelpItem(
                                    question: "How precise is location sharing?",
                                    answer: "By default, only city-level location is shared. You can enable exact location in Settings."
                                ),
                                HelpItem(
                                    question: "How do I go invisible?",
                                    answer: "Go to Settings > Privacy and toggle 'Hide from Others' Maps' to stop sharing your location."
                                )
                            ],
                            isExpanded: expandedSection == "privacy"
                        ) {
                            expandedSection = expandedSection == "privacy" ? nil : "privacy"
                        }

                        // Troubleshooting
                        HelpSection(
                            title: "Troubleshooting",
                            icon: "wrench.and.screwdriver.fill",
                            items: [
                                HelpItem(
                                    question: "Contacts aren't syncing",
                                    answer: "Make sure you've granted contact permissions in Settings > TravelPact > Contacts."
                                ),
                                HelpItem(
                                    question: "Location isn't updating",
                                    answer: "Check that location services are enabled in Settings > Privacy & Security > Location Services."
                                ),
                                HelpItem(
                                    question: "Can't sign in",
                                    answer: "Make sure you're entering your phone number with the correct country code."
                                )
                            ],
                            isExpanded: expandedSection == "troubleshooting"
                        ) {
                            expandedSection = expandedSection == "troubleshooting" ? nil : "troubleshooting"
                        }

                        // Contact Support
                        VStack(spacing: 16) {
                            Text("Still need help?")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            VStack(spacing: 12) {
                                // Email Support
                                Button(action: {
                                    if let url = URL(string: "mailto:support@travelpact.io") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 18))
                                        Text("Email Support")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.blue, Color.purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }

                                // Visit Website
                                Button(action: {
                                    if let url = URL(string: "https://travelpact.io/help") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "safari.fill")
                                            .font(.system(size: 18))
                                        Text("Visit Help Center")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Help")
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
        .preferredColorScheme(.dark)
    }
}

struct HelpSection: View {
    let title: String
    let icon: String
    let items: [HelpItem]
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 28)

                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
            }

            if isExpanded {
                VStack(spacing: 16) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.question)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white)

                            Text(item.answer)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
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

struct HelpItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}