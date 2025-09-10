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
            // Header
            HStack {
                // Contact icon/initials
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
                }
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(locationName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
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
            
            // Action buttons
            HStack(spacing: 16) {
                // Message button
                Button(action: {
                    sendMessage()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 16))
                        Text("Message")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Call button
                if let phone = contact.phoneNumber {
                    Button(action: {
                        callContact(phone: phone)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 16))
                            Text("Call")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
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