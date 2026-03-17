import Foundation
import Supabase
import Auth
import AuthenticationServices
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Auth")

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

    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        currentUser = session.user
        logger.info("Signed in with Apple — user: \(session.user.id)")
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
    }

    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signIn(email: email, password: password)
        currentUser = session.user
        logger.info("Signed in with email — user: \(session.user.id)")
    }

    // MARK: - Sign Out

    func signOut() async {
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
