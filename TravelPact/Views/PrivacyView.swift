import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Privacy Overview
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your Privacy Matters", systemImage: "lock.shield.fill")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("TravelPact is designed with privacy at its core. You have complete control over your location sharing.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )

                        // Privacy Features
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Privacy Features")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            PrivacyFeature(
                                icon: "location.slash.fill",
                                title: "Location Control",
                                description: "Choose between city-level or exact location sharing"
                            )

                            PrivacyFeature(
                                icon: "eye.slash.fill",
                                title: "Hide from Maps",
                                description: "Go invisible to all contacts when you need privacy"
                            )

                            PrivacyFeature(
                                icon: "person.crop.circle.badge.checkmark",
                                title: "Contact-Based Sharing",
                                description: "Only share location with contacts you've added"
                            )

                            PrivacyFeature(
                                icon: "bookmark.fill",
                                title: "Waypoint Control",
                                description: "Your travel bookmarks are private until you choose to share"
                            )
                        }

                        // Data Protection
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Data Protection")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 16) {
                                DataPoint(
                                    icon: "lock.fill",
                                    text: "End-to-end encryption for all data"
                                )

                                DataPoint(
                                    icon: "iphone.and.arrow.forward",
                                    text: "Your data never leaves your device without permission"
                                )

                                DataPoint(
                                    icon: "xmark.shield.fill",
                                    text: "No tracking or analytics without consent"
                                )

                                DataPoint(
                                    icon: "trash.fill",
                                    text: "Delete your data anytime"
                                )
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

                        // Privacy Policy Link
                        VStack(spacing: 12) {
                            Button(action: {
                                // TODO: Open privacy policy URL
                                if let url = URL(string: "https://travelpact.io/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Text("View Full Privacy Policy")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }

                            Text("Last updated: January 2025")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Privacy")
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

struct PrivacyFeature: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct DataPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
    }
}