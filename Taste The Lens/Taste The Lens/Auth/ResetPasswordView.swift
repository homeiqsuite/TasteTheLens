import SwiftUI
import os

private let logger = makeLogger(category: "ResetPassword")

struct ResetPasswordView: View {
    let callbackURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didReset = false
    @State private var sessionReady = false

    private let authManager = AuthManager.shared
    private let gold = Theme.gold

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 8) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 40))
                            .foregroundStyle(gold)

                        Text("Set New Password")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(gold)

                        Text("Enter your new password below")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextTertiary)
                    }

                    Spacer().frame(height: 12)

                    if !sessionReady && errorMessage == nil {
                        // Loading while establishing session
                        ProgressView()
                            .tint(gold)
                            .padding()
                        Text("Verifying link...")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextTertiary)
                    } else if didReset {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)

                            Text("Password updated successfully!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.darkTextPrimary)

                            Button {
                                dismiss()
                            } label: {
                                Text("Done")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(gold)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 32)
                        }
                    } else if sessionReady {
                        VStack(spacing: 14) {
                            SecureField("New Password", text: $newPassword)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.newPassword)

                            SecureField("Confirm Password", text: $confirmPassword)
                                .textFieldStyle(AuthTextFieldStyle())
                                .textContentType(.newPassword)

                            Button {
                                Task { await handleReset() }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                } else {
                                    Text("Update Password")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                            }
                            .background(gold)
                            .cornerRadius(12)
                            .disabled(isLoading)
                        }
                        .padding(.horizontal, 32)
                    }

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
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(gold)
                }
            }
        }
        .task {
            await establishSession()
        }
    }

    private func establishSession() async {
        do {
            // Try the SDK's URL handler first (preserves PKCE code_verifier)
            try await authManager.handleSessionFromURL(callbackURL)
            sessionReady = true
        } catch {
            logger.warning("session(from:) failed: \(error), trying code exchange")
            // Fallback: extract code and try direct exchange
            if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                do {
                    try await authManager.exchangeCodeForSession(code)
                    sessionReady = true
                } catch {
                    // Clear any partial session state left by a failed exchange
                    await authManager.clearInvalidSession()
                    errorMessage = "This reset link is invalid or expired. Please request a new one from the app or tastethelens.com/reset-password"
                    logger.error("Failed to exchange reset code: \(error)")
                }
            } else {
                // Clear any partial session state from the failed URL handler
                await authManager.clearInvalidSession()
                errorMessage = "This reset link is invalid or expired. Please request a new one from the app or tastethelens.com/reset-password"
                logger.error("No code found in callback URL: \(callbackURL)")
            }
        }
    }

    private func handleReset() async {
        errorMessage = nil

        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.updatePassword(newPassword)
            withAnimation { didReset = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Password update failed: \(error)")
        }
    }
}
