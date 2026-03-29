import Foundation
import Supabase
import Auth
import AuthenticationServices
import os

private let logger = makeLogger(category: "Auth")

@Observable
final class AuthManager {
    static let shared = AuthManager()

    var currentUser: Auth.User?
    var isAuthenticated: Bool { currentUser != nil }
    var isGuest: Bool { !isAuthenticated }
    var isLoading = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Session Restore

    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            logger.info("Session restored for user: \(session.user.id)")
        } catch {
            logger.info("No existing session to restore")
            currentUser = nil
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        currentUser = session.user

        // Apple only provides fullName on the FIRST sign-in — persist it to auth metadata
        if let fullName, let formatted = PersonNameComponentsFormatter.localizedString(from: fullName, style: .default).nilIfEmpty {
            let existingName = currentUser?.userMetadata["full_name"]?.stringValue
            if existingName == nil || existingName?.isEmpty == true {
                _ = try await supabase.auth.update(user: .init(data: ["full_name": .string(formatted)]))
            }
        }

        logger.info("Signed in with Apple — user: \(session.user.id)")

        // Refresh session to ensure currentUser has latest metadata
        let refreshedSession = try await supabase.auth.session
        currentUser = refreshedSession.user

        await syncDisplayName()
        await PushNotificationService.shared.requestPermission()
    }

    // MARK: - Email Auth

    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(displayName)]
        )
        currentUser = response.user
        logger.info("Signed up with email — user: \(response.user.id)")
        await syncDisplayName()
        await PushNotificationService.shared.requestPermission()
    }

    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signIn(email: email, password: password)
        currentUser = session.user
        logger.info("Signed in with email — user: \(session.user.id)")
        await syncDisplayName()
        await PushNotificationService.shared.requestPermission()
    }

    // MARK: - Forgot Password

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "https://tastethelens.com/reset-password")
        )
        logger.info("Password reset email sent to \(email)")
    }

    func exchangeCodeForSession(_ code: String) async throws {
        let session = try await supabase.auth.exchangeCodeForSession(authCode: code)
        currentUser = session.user
        logger.info("Exchanged reset code for session — user: \(session.user.id)")
    }

    /// Handle a callback URL (e.g. from password reset deep link).
    /// Uses the SDK's built-in handler which includes the stored PKCE code_verifier.
    func handleSessionFromURL(_ url: URL) async throws {
        let session = try await supabase.auth.session(from: url)
        currentUser = session.user
        logger.info("Session restored from URL — user: \(session.user.id)")
    }

    func updatePassword(_ newPassword: String) async throws {
        try await supabase.auth.update(user: .init(password: newPassword))
        logger.info("Password updated successfully")
    }

    // MARK: - Display Name

    var needsDisplayName: Bool {
        guard isAuthenticated else { return false }
        let name = currentUser?.userMetadata["full_name"]?.stringValue
        return name == nil || name?.trimmingCharacters(in: .whitespaces).isEmpty == true
    }

    func updateDisplayName(_ name: String) async throws {
        currentUser = try await supabase.auth.update(user: .init(data: ["full_name": .string(name)]))
        await syncDisplayName()
        logger.info("Updated display name to: \(name)")
    }

    func syncDisplayName() async {
        guard let userId = currentUser?.id.uuidString.lowercased() else { return }
        do {
            try await supabase.from("users")
                .upsert([
                    "id": userId,
                    "display_name": displayName
                ], onConflict: "id")
                .execute()
        } catch {
            logger.error("Failed to sync display name: \(error)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        await PushNotificationService.shared.unregisterToken()
        do {
            try await supabase.auth.signOut()
            currentUser = nil
            logger.info("Signed out successfully")
        } catch {
            logger.error("Sign out failed: \(error)")
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let userId = currentUser?.id else { return }

        // Delete user's recipes from Supabase
        try await supabase.from("recipes")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()

        // Delete user profile row
        try await supabase.from("users")
            .delete()
            .eq("id", value: userId.uuidString)
            .execute()

        // Sign out locally
        try await supabase.auth.signOut()
        currentUser = nil
        logger.info("Account deleted and signed out")
    }

    // MARK: - User Display Info

    var displayName: String {
        currentUser?.userMetadata["full_name"]?.stringValue
        ?? currentUser?.userMetadata["name"]?.stringValue
        ?? currentUser?.email?.components(separatedBy: "@").first
        ?? "User"
    }

    var email: String {
        currentUser?.email ?? ""
    }

    var memberSinceDate: Date {
        currentUser?.createdAt ?? Date()
    }
}

// MARK: - Apple Sign-In Helper

final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    var onCompletion: ((Result<(String, String), Error>) -> Void)?
    var currentNonce: String?

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            onCompletion?(.failure(AuthError.missingCredentials))
            return
        }
        onCompletion?(.success((idToken, nonce)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }
}

enum AuthError: LocalizedError {
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Could not retrieve Apple Sign-In credentials."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
    }
}
