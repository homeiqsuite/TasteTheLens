import Foundation
import UserNotifications
import os

private let logger = makeLogger(category: "CreditExpiry")

/// Schedules local notifications to warn subscribers about expiring credits.
@MainActor
final class CreditExpiryNotificationService {
    static let shared = CreditExpiryNotificationService()

    private static let notificationId = "credit-expiry-warning"
    private static let warningDaysBefore = 3

    private init() {}

    /// Schedule a local notification 3 days before subscription credits reset.
    /// Safe to call repeatedly — cancels any existing notification before scheduling.
    func scheduleExpiryNotificationIfNeeded() {
        let usage = UsageTracker.shared

        // Only for active subscribers with credits that could expire
        guard EntitlementManager.shared.isSubscriber,
              let resetDate = usage.creditResetDate,
              usage.subscriptionCredits + usage.rolledOverCredits > 0 else {
            cancelNotification()
            return
        }

        // Calculate fire date: 3 days before reset, at 10:00 AM local
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -Self.warningDaysBefore, to: resetDate),
              fireDate > Date() else {
            // Too late to schedule (reset is within 3 days or past) — skip
            return
        }

        var fireDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        fireDateComponents.hour = 10
        fireDateComponents.minute = 0

        let expiringCount = usage.subscriptionCredits + usage.rolledOverCredits

        let content = UNMutableNotificationContent()
        content.title = "Credits expiring soon"
        content.body = "You have \(expiringCount) subscription credits that will reset in \(Self.warningDaysBefore) days. Use them before they refresh!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: fireDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationId, content: content, trigger: trigger)

        // Cancel existing before scheduling new
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationId])

        center.add(request) { error in
            if let error {
                logger.warning("Failed to schedule credit expiry notification: \(error)")
            } else {
                logger.info("Credit expiry notification scheduled for \(fireDateComponents.month ?? 0)/\(fireDateComponents.day ?? 0) — \(expiringCount) credits expiring")
            }
        }
    }

    /// Cancel any pending credit expiry notification.
    func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
        logger.info("Credit expiry notification cancelled")
    }
}
