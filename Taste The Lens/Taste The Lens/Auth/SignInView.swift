import SwiftUI
import AuthenticationServices
import CryptoKit
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "SignIn")

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showEmailForm = false
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)
    private let authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome to")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Taste The Lens")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(gold)
                        Text("Sign in to sync your recipes across devices")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }

                    Spacer().frame(height: 20)

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
                        Text("or")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.horizontal, 12)
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
                    }
                    .padding(.horizontal, 32)

                    // Email sign-in toggle
                    if showEmailForm {
                        emailForm
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showEmailForm = true
                            }
                        } label: {
                            Text("Continue with Email")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(gold)
                }
            }
        }
    }

    // MARK: - Email Form

    private var emailForm: some View {
        VStack(spacing: 14) {
            if isSignUp {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(AuthTextFieldStyle())
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            TextField("Email", text: $email)
                .textFieldStyle(AuthTextFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .textFieldStyle(AuthTextFieldStyle())
                .textContentType(isSignUp ? .newPassword : .password)

            Button {
                Task { await handleEmailAuth() }
            } label: {
                if authManager.isLoading {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(gold)
            .cornerRadius(12)
            .disabled(authManager.isLoading)

            Button {
                withAnimation { isSignUp.toggle() }
            } label: {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Handlers

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Could not retrieve Apple credentials."
                return
            }
            Task {
                do {
                    try await authManager.signInWithApple(idToken: idToken, nonce: nonce)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    logger.error("Apple sign-in failed: \(error)")
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
            logger.error("Apple sign-in error: \(error)")
        }
    }

    private func handleEmailAuth() async {
        errorMessage = nil
        do {
            if isSignUp {
                let name = displayName.isEmpty ? email.components(separatedBy: "@").first ?? "User" : displayName
                try await authManager.signUp(email: email, password: password, displayName: name)
            } else {
                try await authManager.signInWithEmail(email: email, password: password)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Email auth failed: \(error)")
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Text Field Style

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .foregroundStyle(.white)
            .font(.system(size: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}
