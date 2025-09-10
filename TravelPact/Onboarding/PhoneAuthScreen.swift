import SwiftUI
import Supabase
import Auth

struct PhoneAuthScreen: View {
    @Binding var currentStep: OnboardingStep
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var showVerification = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var countryCode = "+1"
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Globe background with blur overlay
            OnboardingGlobeBackground(showWaypoints: false, waypoints: [])
                .ignoresSafeArea()
            
            // Blurred overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .background(
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation {
                            if showVerification {
                                showVerification = false
                                verificationCode = ""
                            } else {
                                currentStep = .welcome
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Image(systemName: showVerification ? "lock.shield.fill" : "phone.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .white.opacity(0.3), radius: 10)
                            
                            Text(showVerification ? "Verify Your Number" : "Enter Your Phone")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(showVerification ? 
                                 "We sent a code to \(countryCode) \(formatPhoneNumber(phoneNumber))" :
                                 "We'll send you a verification code")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 20) {
                            if !showVerification {
                                HStack(spacing: 12) {
                                    Menu {
                                        Button("+1 USA/Canada") { countryCode = "+1" }
                                        Button("+44 UK") { countryCode = "+44" }
                                        Button("+33 France") { countryCode = "+33" }
                                        Button("+49 Germany") { countryCode = "+49" }
                                        Button("+52 Mexico") { countryCode = "+52" }
                                        Button("+61 Australia") { countryCode = "+61" }
                                        Button("+81 Japan") { countryCode = "+81" }
                                        Button("+86 China") { countryCode = "+86" }
                                        Button("+91 India") { countryCode = "+91" }
                                        Button("+7 Russia") { countryCode = "+7" }
                                        Button("+55 Brazil") { countryCode = "+55" }
                                        Button("+27 South Africa") { countryCode = "+27" }
                                        Button("+82 South Korea") { countryCode = "+82" }
                                        Button("+39 Italy") { countryCode = "+39" }
                                        Button("+34 Spain") { countryCode = "+34" }
                                    } label: {
                                        HStack {
                                            Text(countryCode)
                                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                                .foregroundColor(.white)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.1))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(.ultraThinMaterial)
                                                )
                                        )
                                    }
                                    
                                    LiquidGlassTextField(
                                        placeholder: "Phone Number",
                                        text: $phoneNumber,
                                        keyboardType: .phonePad
                                    )
                                }
                            } else {
                                VStack(spacing: 20) {
                                    // OTP Input Field
                                    VStack(spacing: 12) {
                                        Text("Enter verification code")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        // Single text field for easy input
                                        TextField("000000", text: $verificationCode)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.center)
                                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: 200)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white.opacity(0.1))
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .fill(.ultraThinMaterial)
                                                    )
                                            )
                                            .focused($isCodeFieldFocused)
                                            .onChange(of: verificationCode) { _, newValue in
                                                // Only allow numbers and limit to 6 digits
                                                let filtered = newValue.filter { $0.isNumber }
                                                if filtered.count > 6 {
                                                    verificationCode = String(filtered.prefix(6))
                                                } else {
                                                    verificationCode = filtered
                                                }
                                            }
                                            .onAppear {
                                                // Auto-focus when view appears
                                                isCodeFieldFocused = true
                                            }
                                        
                                        // Visual representation of code entry
                                        HStack(spacing: 12) {
                                            ForEach(0..<6, id: \.self) { index in
                                                VerificationCodeField(
                                                    text: verificationCode,
                                                    index: index
                                                )
                                            }
                                        }
                                    }
                                    
                                    Button(action: resendCode) {
                                        Text("Resend Code")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .disabled(isLoading)
                                }
                            }
                            
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: showVerification ? verifyCode : sendCode) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(showVerification ? "Verify" : "Send Code")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                            .disabled(showVerification ? verificationCode.count < 6 : phoneNumber.isEmpty)
                            .disabled(isLoading)
                        }
                        .padding(.horizontal, 32)
                        
                        VStack(spacing: 12) {
                            Text("By continuing, you agree to our")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 4) {
                                Button("Terms of Service") {}
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("and")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Button("Privacy Policy") {}
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                
                Spacer()
            }
        }
        .onChange(of: verificationCode) { _, newValue in
            if newValue.count == 6 {
                verifyCode()
            }
        }
    }
    
    private func sendCode() {
        guard !phoneNumber.isEmpty else { 
            errorMessage = "Please enter a phone number"
            return 
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Clean the phone number - remove spaces, dashes, parentheses
                let cleanedNumber = phoneNumber
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                
                // Ensure the phone number doesn't start with 0
                let trimmedNumber = cleanedNumber.hasPrefix("0") ? String(cleanedNumber.dropFirst()) : cleanedNumber
                
                // Combine country code with phone number
                let fullPhoneNumber = "\(countryCode)\(trimmedNumber)"
                
                print("📱 Attempting to send OTP to: \(fullPhoneNumber)")
                
                try await SupabaseManager.shared.auth.signInWithOTP(
                    phone: fullPhoneNumber
                )
                
                print("✅ OTP sent successfully to \(fullPhoneNumber)")
                
                await MainActor.run {
                    withAnimation {
                        showVerification = true
                        isLoading = false
                    }
                }
            } catch {
                print("❌ Error sending OTP: \(error)")
                print("❌ Error details: \(String(describing: error))")
                
                await MainActor.run {
                    // More specific error messages based on common issues
                    if let authError = error as? AuthError {
                        errorMessage = authError.localizedDescription
                    } else if error.localizedDescription.contains("rate") {
                        errorMessage = "Too many attempts. Please wait a moment and try again."
                    } else if error.localizedDescription.contains("invalid") {
                        errorMessage = "Invalid phone number format. Please check and try again."
                    } else {
                        errorMessage = "Failed to send code: \(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyCode() {
        guard verificationCode.count == 6 else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Use the same phone number format as sendCode
                let cleanedNumber = phoneNumber
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                
                let trimmedNumber = cleanedNumber.hasPrefix("0") ? String(cleanedNumber.dropFirst()) : cleanedNumber
                let fullPhoneNumber = "\(countryCode)\(trimmedNumber)"
                
                print("🔐 Attempting to verify OTP for: \(fullPhoneNumber)")
                
                try await SupabaseManager.shared.auth.verifyOTP(
                    phone: fullPhoneNumber,
                    token: verificationCode,
                    type: .sms
                )
                
                print("✅ OTP verified successfully")
                
                // Check authentication status to see if profile exists
                authManager.checkAuthStatus()
                
                // Wait a moment for the auth check to complete
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    // For new users, we should go to profile creation
                    // The authManager will handle the navigation
                    isLoading = false
                    
                    // If this is a new user (no profile), move to profile creation
                    if authManager.isAuthenticated && !authManager.hasCompletedProfile {
                        withAnimation {
                            currentStep = .profileCreation
                        }
                    }
                }
            } catch {
                print("❌ Error verifying OTP: \(error)")
                
                await MainActor.run {
                    if let authError = error as? AuthError {
                        errorMessage = authError.localizedDescription
                    } else if error.localizedDescription.contains("expired") {
                        errorMessage = "Code expired. Please request a new one."
                    } else {
                        errorMessage = "Invalid code. Please check and try again."
                    }
                    isLoading = false
                    verificationCode = ""
                }
            }
        }
    }
    
    private func resendCode() {
        showVerification = false
        verificationCode = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sendCode()
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        if cleaned.count >= 10 {
            let areaCode = String(cleaned.prefix(3))
            let middle = String(cleaned.dropFirst(3).prefix(3))
            let last = String(cleaned.dropFirst(6))
            return "(\(areaCode)) \(middle)-\(last)"
        }
        return number
    }
}

struct VerificationCodeField: View {
    let text: String
    let index: Int
    
    var digit: String {
        if index < text.count {
            let idx = text.index(text.startIndex, offsetBy: index)
            return String(text[idx])
        }
        return ""
    }
    
    var body: some View {
        Text(digit)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.white.opacity(digit.isEmpty ? 0.2 : 0.5),
                                lineWidth: 1
                            )
                    )
            )
    }
}