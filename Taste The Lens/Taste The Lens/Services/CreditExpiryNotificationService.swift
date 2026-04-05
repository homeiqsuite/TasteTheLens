import Foundation
import UserNotifications
import os

private let logger = makeLogger(category: "CreditExpiry")

/// Previously scheduled notifications for expiring subscription credits.
/// No longer needed under the pure credits model (credits never expire).
/// Kept as a stub to avoid Xcode project file changes.
@MainActor
final class CreditExpiryNotificationService {
    static let shared = CreditExpiryNotificationService()

    private static let notificationId = "credit-expiry-warning"

    private init() {}

    /// No-op: credits no longer expire under the pure credits model.
    func scheduleExpiryNotificationIfNeeded() {
        // Cancel any previously scheduled notification from the old model
        cancelNotification()
    }

    /// Cancel any pending credit expiry notification.
    func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
    }
}
