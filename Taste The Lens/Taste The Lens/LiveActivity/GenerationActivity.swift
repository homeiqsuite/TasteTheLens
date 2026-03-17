import ActivityKit
import SwiftUI

struct GenerationActivityAttributes: ActivityAttributes {
    /// Fixed context that doesn't change during the activity
    struct ContentState: Codable, Hashable {
        var phase: String       // "Screening", "Analyzing", "Generating", "Complete"
        var progress: Double    // 0.0 to 1.0
        var statusMessage: String
    }

    var dishSourceDescription: String // Brief description of what was photographed
}

// MARK: - Live Activity Manager

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<GenerationActivityAttributes>?

    private init() {}

    func startGeneration(sourceDescription: String = "your photo") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = GenerationActivityAttributes(
            dishSourceDescription: sourceDescription
        )
        let initialState = GenerationActivityAttributes.ContentState(
            phase: "Screening",
            progress: 0.1,
            statusMessage: "Checking image..."
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Live Activities not available — silently skip
        }
    }

    func updatePhase(_ phase: String, progress: Double, status: String) {
        guard let activity = currentActivity else { return }

        let state = GenerationActivityAttributes.ContentState(
            phase: phase,
            progress: progress,
            statusMessage: status
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endGeneration(dishName: String?) {
        guard let activity = currentActivity else { return }

        let finalState = GenerationActivityAttributes.ContentState(
            phase: "Complete",
            progress: 1.0,
            statusMessage: dishName ?? "Recipe ready!"
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 5))
            currentActivity = nil
        }
    }

    func cancelGeneration() {
        guard let activity = currentActivity else { return }

        let cancelState = GenerationActivityAttributes.ContentState(
            phase: "Cancelled",
            progress: 0,
            statusMessage: "Generation cancelled"
        )

        Task {
            await activity.end(.init(state: cancelState, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
