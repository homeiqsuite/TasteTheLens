import SwiftUI
import os

private let logger = makeLogger(category: "ResetPassword")

struct ResetPasswordView: View {
    let code: String

    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didReset = false

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

                    if didReset {
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
                    } else {
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
            await exchangeCode()
        }
    }

    private func exchangeCode() async {
        do {
            try await authManager.exchangeCodeForSession(code)
        } catch {
            errorMessage = "This reset link is invalid or expired. Please request a new one."
            logger.error("Failed to exchange reset code: \(error)")
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
