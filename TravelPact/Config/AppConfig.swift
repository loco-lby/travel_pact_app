import Foundation

struct AppConfig {
    static let isDebugMode = true
    
    // Phone auth settings
    static let phoneAuthSettings = PhoneAuthSettings()
    
    struct PhoneAuthSettings {
        // Minimum phone number length (without country code)
        let minPhoneLength = 7
        let maxPhoneLength = 15
        
        // OTP settings
        let otpLength = 6
        let otpResendDelay = 30 // seconds
        
        // Twilio Verify specific settings
        let useTestMode = false // Set to true to use test phone numbers
        let testPhoneNumbers = [
            "+15555550100": "123456", // Test US number
            "+447700900000": "123456" // Test UK number
        ]
    }
    
    // Logging
    static func log(_ message: String, type: LogType = .info) {
        #if DEBUG
        let prefix: String
        switch type {
        case .info:
            prefix = "ℹ️ INFO"
        case .warning:
            prefix = "⚠️ WARNING"
        case .error:
            prefix = "❌ ERROR"
        case .success:
            prefix = "✅ SUCCESS"
        }
        print("\(prefix): \(message)")
        #endif
    }
    
    enum LogType {
        case info, warning, error, success
    }
}