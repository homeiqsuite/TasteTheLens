import Foundation
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Notifications")

enum AppNotificationType {
    case challengeAccepted(challengeTitle: String)
    case submissionReceived(challengeTitle: String)
    case submissionUpvoted(count: Int)
}

struct AppNotification: Identifiable {
    let id = UUID()
    let type: AppNotificationType
    let createdAt = Date()

    var message: String {
        switch type {
        case .challengeAccepted(let title):
            "Someone accepted your \"\(title)\" challenge!"
        case .submissionReceived(let title):
            "New submission on your \"\(title)\" challenge!"
        case .submissionUpvoted(let count):
            "Your submission got \(count) new upvotes!"
        }
    }

    var icon: String {
        switch type {
        case .challengeAccepted: "flame.fill"
        case .submissionReceived: "photo.fill"
        case .submissionUpvoted: "arrow.up.circle.fill"
        }
    }
}

@Observable @MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    var notifications: [AppNotification] = []
    var currentBanner: AppNotification?

    private init() {}

    func showBanner(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        currentBanner = notification

        Task {
            try? await Task.sleep(for: .seconds(4))
            if currentBanner?.id == notification.id {
                currentBanner = nil
            }
        }
    }

    func dismissBanner() {
        currentBanner = nil
    }
}
