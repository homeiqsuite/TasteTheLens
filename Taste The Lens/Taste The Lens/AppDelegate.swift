import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import os

private let logger = makeLogger(category: "AppDelegate")

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set explicit URL cache limits to prevent "cache storage usage exceeds limit" warnings.
        // The app makes large AI API calls and downloads generated images — without explicit limits
        // iOS hits its own internal threshold and purges the entire persistent cache.
        URLCache.shared = URLCache(
            memoryCapacity: 10 * 1024 * 1024,   // 10 MB in-memory
            diskCapacity: 50 * 1024 * 1024,      // 50 MB on-disk
            directory: nil
        )

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - APNs Token → Firebase

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        logger.info("APNs device token registered with Firebase")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Failed to register for remote notifications: \(error)")
    }

    // MARK: - FCM Token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        logger.info("FCM token received")
        Task { @MainActor in
            await PushNotificationService.shared.registerFCMToken(token)
        }
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    // MARK: - Notification Tap → Deep Link

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deep_link"] as? String,
           let url = URL(string: deepLink) {
            await UIApplication.shared.open(url)
        }
    }
}
