import SwiftUI

public struct AuthView: View {
    @ObservedObject var authService = AuthService.shared
    
    @State private var isSignUp: Bool = false
    @State private var email: String = "evan@prodbyevan.com"
    @State private var password: String = "password123"
    @State private var username: String = "prodbyevan!"
    
    public init() {}
    
    public var body: some View {
        ZStack {
            BounceTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Brutalist Logo / Brand Stamp
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(BounceTheme.accent)
                                .frame(width: 12, height: 12)
                            Text("BOUNCE")
                                .font(BounceTheme.mono(24, weight: .bold))
                                .foregroundColor(BounceTheme.textPrimary)
                                .tracking(3.0)
                        }
                        
                        Text("LOSSLESS AUDIO VAULT FOR MUSIC PRODUCERS")
                            .font(BounceTheme.mono(9, weight: .semibold))
                            .foregroundColor(BounceTheme.accent)
                            .tracking(1.5)
                    }
                    .padding(.top, 48)
                    
                    // Form Box
                    VStack(alignment: .leading, spacing: 16) {
                        Text(isSignUp ? "CREATE CREATOR ACCOUNT" : "CREATOR SIGN IN")
                            .font(BounceTheme.mono(12, weight: .bold))
                            .foregroundColor(BounceTheme.textPrimary)
                            .tracking(1.0)
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EMAIL")
                                .font(BounceTheme.mono(10, weight: .bold))
                                .foregroundColor(BounceTheme.textSecondary)
                            TextField("producer@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(BounceTheme.mono(13))
                                .padding(12)
                                .background(BounceTheme.surfaceElevated)
                                .foregroundColor(BounceTheme.textPrimary)
                                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                        }
                        
                        // Username Field (on Sign Up)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("PRODUCER MONIKER")
                                        .font(BounceTheme.mono(10, weight: .bold))
                                        .foregroundColor(BounceTheme.textSecondary)
                                    Spacer()
                                    Text("e.g. prodbyevan!")
                                        .font(BounceTheme.mono(9))
                                        .foregroundColor(BounceTheme.accent)
                                }
                                TextField("prodbyevan!", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(BounceTheme.mono(13))
                                    .padding(12)
                                    .background(BounceTheme.surfaceElevated)
                                    .foregroundColor(BounceTheme.textPrimary)
                                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                            }
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORD")
                                .font(BounceTheme.mono(10, weight: .bold))
                                .foregroundColor(BounceTheme.textSecondary)
                            SecureField("••••••••", text: $password)
                                .font(BounceTheme.mono(13))
                                .padding(12)
                                .background(BounceTheme.surfaceElevated)
                                .foregroundColor(BounceTheme.textPrimary)
                                .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                        }
                        
                        // Error message
                        if let error = authService.errorMessage {
                            Text(error)
                                .font(BounceTheme.sans(11))
                                .foregroundColor(BounceTheme.alert)
                        }
                        
                        // Action Button
                        Button {
                            submitAuth()
                        } label: {
                            if authService.isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(isSignUp ? "REGISTER ACCOUNT" : "SIGN IN")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(BrutalistButtonStyle(isPrimary: true))
                        .disabled(authService.isLoading)
                        .padding(.top, 4)
                        
                        // Switch Mode
                        Button {
                            isSignUp.toggle()
                            authService.errorMessage = nil
                        } label: {
                            Text(isSignUp ? "ALREADY HAVE AN ACCOUNT? SIGN IN" : "NEED AN ACCOUNT? REGISTER")
                                .font(BounceTheme.mono(10, weight: .bold))
                                .foregroundColor(BounceTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(20)
                    .background(BounceTheme.surface)
                    .overlay(Rectangle().stroke(BounceTheme.surfaceBorder, lineWidth: 1))
                    .padding(.horizontal, 24)
                    
                    // Quick Demo Studio Access
                    VStack(spacing: 8) {
                        Text("TRYING THE APP?")
                            .font(BounceTheme.mono(9))
                            .foregroundColor(BounceTheme.textMuted)
                        
                        Button {
                            authService.setupDemoProducer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                Text("ENTER AS DEMO PRODUCER (PRODBYEVAN!)")
                            }
                            .font(BounceTheme.mono(10, weight: .bold))
                            .foregroundColor(BounceTheme.accent)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
    }
    
    private func submitAuth() {
        Task {
            if isSignUp {
                _ = await authService.signUp(email: email, password: password, username: username)
            } else {
                _ = await authService.signIn(email: email, password: password)
            }
        }
    }
}
