import Foundation
import os

private let logger = makeLogger(category: "Notifications")

enum AppNotificationType {
    case challengeAccepted(challengeTitle: String)
    case submissionReceived(challengeTitle: String)
    case submissionUpvoted(count: Int)
    case menuInvitation(menuTheme: String)
    case menuCourseAdded(menuTheme: String)
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
        case .menuInvitation(let theme):
            "You've been invited to the \"\(theme)\" tasting menu!"
        case .menuCourseAdded(let theme):
            "A new course was added to \"\(theme)\""
        }
    }

    var icon: String {
        switch type {
        case .challengeAccepted: "flame.fill"
        case .submissionReceived: "photo.fill"
        case .submissionUpvoted: "arrow.up.circle.fill"
        case .menuInvitation: "envelope.fill"
        case .menuCourseAdded: "menucard.fill"
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
