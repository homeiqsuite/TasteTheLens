import Foundation
import UserNotifications
import UIKit
import Supabase
import os

private let logger = makeLogger(category: "PushNotifications")

/// Notification preference categories that map to `users.notification_preferences` JSONB column.
struct NotificationPreferences: Codable, Equatable {
    var challengeActivity: Bool
    var tastingMenuUpdates: Bool
    var weeklyInspiration: Bool

    enum CodingKeys: String, CodingKey {
        case challengeActivity = "challenge_activity"
        case tastingMenuUpdates = "tasting_menu_updates"
        case weeklyInspiration = "weekly_inspiration"
    }

    static let `default` = NotificationPreferences(
        challengeActivity: true,
        tastingMenuUpdates: true,
        weeklyInspiration: true
    )
}

@Observable @MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    var preferences = NotificationPreferences.default
    var permissionStatus: UNAuthorizationStatus = .notDetermined

    /// The current FCM token, kept in memory for sign-out cleanup.
    private var currentFCMToken: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Permission

    /// Requests notification permission and registers for remote notifications.
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                logger.info("Push notification permission granted")
            } else {
                logger.info("Push notification permission denied")
            }
            await refreshPermissionStatus()
        } catch {
            logger.error("Failed to request notification permission: \(error)")
        }
    }

    /// Refreshes the cached permission status (for UI display).
    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    // MARK: - FCM Token Registration

    /// Upserts the FCM token to Supabase `device_tokens` table.
    func registerFCMToken(_ token: String) async {
        currentFCMToken = token

        guard let userId = AuthManager.shared.currentUser?.id else {
            logger.info("Skipping FCM token registration — no authenticated user")
            return
        }

        do {
            try await supabase.from("device_tokens").upsert(
                DeviceTokenDTO(userId: userId.uuidString, fcmToken: token),
                onConflict: "user_id,fcm_token"
            ).execute()
            logger.info("FCM token registered for user \(userId)")
        } catch {
            logger.error("Failed to register FCM token: \(error)")
        }
    }

    /// Deletes the current device's token from Supabase on sign-out.
    func unregisterToken() async {
        guard let token = currentFCMToken,
              let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            try await supabase.from("device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("fcm_token", value: token)
                .execute()
            logger.info("FCM token unregistered for user \(userId)")
        } catch {
            logger.error("Failed to unregister FCM token: \(error)")
        }

        currentFCMToken = nil
    }

    // MARK: - Preferences

    /// Loads notification preferences from Supabase `users` table.
    func loadPreferences() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            let response: UserNotificationPrefsDTO = try await supabase.from("users")
                .select("notification_preferences")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            if let prefs = response.notificationPreferences {
                preferences = prefs
            }
            logger.info("Loaded notification preferences")
        } catch {
            logger.error("Failed to load notification preferences: \(error)")
        }
    }

    /// Saves notification preferences to Supabase `users` table.
    func savePreferences() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        do {
            try await supabase.from("users")
                .update(["notification_preferences": preferences])
                .eq("id", value: userId.uuidString)
                .execute()
            logger.info("Saved notification preferences")
        } catch {
            logger.error("Failed to save notification preferences: \(error)")
        }
    }
}

// MARK: - DTOs

private struct DeviceTokenDTO: Encodable {
    let userId: String
    let fcmToken: String
    let platform = "ios"
    let updatedAt = ISO8601DateFormatter().string(from: Date())

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fcmToken = "fcm_token"
        case platform
        case updatedAt = "updated_at"
    }
}

private struct UserNotificationPrefsDTO: Decodable {
    let notificationPreferences: NotificationPreferences?

    enum CodingKeys: String, CodingKey {
        case notificationPreferences = "notification_preferences"
    }
}
