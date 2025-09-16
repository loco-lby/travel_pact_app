import SwiftUI
import CoreLocation
import UIKit

struct ContactLocationCard: View {
    let contact: TravelPactContact
    let locationData: ContactLocationData
    let onClose: () -> Void
    
    @State private var showingMessageComposer = false
    @State private var showingCallAlert = false
    
    private var locationName: String {
        locationData.locationName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with enhanced status display
            HStack {
                // Contact icon/initials with status indicator
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.8),
                                    Color.orange.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Location assignment status indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "location.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                        .offset(x: 14, y: -14)
                }
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Location status with icon
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        
                        Text("Location: \(locationName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    // Address details if available
                    if let address = locationData.address, address != locationName {
                        Text(address)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(16)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Enhanced action buttons
            VStack(spacing: 12) {
                // Location management button
                Button(action: {
                    // TODO: Show location change interface
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 16))
                        Text("Change Location")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Communication buttons
                HStack(spacing: 12) {
                    // Message button
                    Button(action: {
                        sendMessage()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 14))
                            Text("Message")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Call button
                    if let phone = contact.phoneNumber {
                        Button(action: {
                            callContact(phone: phone)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                Text("Call")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    } else {
                        // Invite button if no phone number
                        Button(action: {
                            inviteToTravelPact()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                Text("Invite")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
            .padding(16)
            .padding(.top, -8)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20)
    }
    
    private func sendMessage() {
        // Try to open Messages app with pre-filled recipient
        if let phone = contact.phoneNumber {
            let sms = "sms:\(phone)"
            if let url = URL(string: sms), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func inviteToTravelPact() {
        // Send invite SMS if phone number is available
        if let phone = contact.phoneNumber {
            let message = "Hey! I've added you to my travel map on TravelPact. Join to stay in touch and share your adventures: https://travelpact.io"
            let sms = "sms:\(phone)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: sms), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func callContact(phone: String) {
        // Clean phone number and attempt to call
        let cleanedPhone = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        if let url = URL(string: "tel://\(cleanedPhone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
}

extension TravelPactContact {
    var initials: String {
        let components = name.split(separator: " ")
        let firstInitial = components.first?.first ?? Character(" ")
        let lastInitial = components.count > 1 ? components.last?.first ?? Character(" ") : Character(" ")
        
        if components.count == 1 {
            return String(firstInitial).uppercased()
        }
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}