import Foundation
import UserNotifications
import os

private let logger = makeLogger(category: "DailyReminder")

/// Schedules a once-a-day **local** re-engagement notification to invite the user
/// back to the camera. Unlike `PushNotificationService` (remote / Firebase), this
/// needs no server — everything is scheduled on-device.
///
/// iOS caps an app at 64 pending notifications, and a single repeating trigger can
/// only ever show one fixed message. To keep the copy fresh and funny, we instead
/// schedule a *rolling window* of distinct one-shot reminders (one per day) and
/// re-extend that window every time the app becomes active.
@Observable @MainActor
final class DailyReminderService {
    static let shared = DailyReminderService()

    private static let idPrefix = "daily-reminder-"
    private static let enabledKey = "dailyReminderEnabled"
    private static let hourKey = "dailyReminderHour"
    private static let minuteKey = "dailyReminderMinute"

    /// How many days ahead we schedule. Refreshed on every foreground so the
    /// window keeps sliding forward and never runs dry.
    private static let windowDays = 14

    /// Opt-out: on by default, but reminders only ever fire once the user has
    /// granted notification permission (handled by `PushNotificationService`).
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            Task { await refresh() }
        }
    }

    /// Fire time (24h). Defaults to 6:30 PM — prime "what's for dinner?" hour.
    private(set) var hour: Int
    private(set) var minute: Int

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.enabledKey) == nil {
            defaults.set(true, forKey: Self.enabledKey)
        }
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        hour = defaults.object(forKey: Self.hourKey) as? Int ?? 18
        minute = defaults.object(forKey: Self.minuteKey) as? Int ?? 30
    }

    /// Updates the daily fire time and reschedules.
    func setTime(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
        let defaults = UserDefaults.standard
        defaults.set(hour, forKey: Self.hourKey)
        defaults.set(minute, forKey: Self.minuteKey)
        Task { await refresh() }
    }

    /// Re-evaluates and reschedules the rolling reminder window. Safe to call often
    /// (launch + every foreground). No-ops gracefully when disabled or unauthorized.
    func refresh() async {
        cancelAll()

        guard isEnabled else {
            logger.info("Daily reminders disabled — cleared pending requests")
            return
        }

        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus

        // If permission was never decided, only prompt once the user has felt the
        // app's value (generated their first recipe). Asking cold on first launch
        // tanks opt-in rates, so we wait for a delight moment. This makes daily
        // reminders work even for users who never sign in.
        if status == .notDetermined, hasEarnedPermissionPrompt {
            status = await requestPermission()
        }

        guard status == .authorized || status == .provisional || status == .ephemeral else {
            logger.info("Notification permission not granted — skipping daily reminders")
            return
        }

        scheduleWindow()
    }

    /// True once the user has generated their first recipe — set by `RecipeCardView`
    /// via `@AppStorage("hasGeneratedFirstRecipe")`.
    private var hasEarnedPermissionPrompt: Bool {
        UserDefaults.standard.bool(forKey: "hasGeneratedFirstRecipe")
    }

    /// Requests notification authorization for local reminders and returns the
    /// resulting status. Does not register for remote notifications — that stays
    /// the responsibility of `PushNotificationService` on authenticated launch.
    @discardableResult
    private func requestPermission() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            logger.info("Daily reminder permission prompt — granted: \(granted)")
        } catch {
            logger.error("Daily reminder permission request failed: \(error)")
        }
        return await center.notificationSettings().authorizationStatus
    }

    /// Removes every reminder this service may have scheduled.
    func cancelAll() {
        let ids = (0..<Self.windowDays).map { "\(Self.idPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Scheduling

    private func scheduleWindow() {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        // Start today if the fire time is still ahead of us, otherwise tomorrow.
        var startOffset = 0
        if let todayFire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now),
           todayFire <= now {
            startOffset = 1
        }

        // Rotate the message pool from a random anchor so the copy varies across
        // reschedules, then walk it sequentially so no two consecutive days repeat.
        let anchor = Int.random(in: 0..<Self.messages.count)

        for i in 0..<Self.windowDays {
            guard let day = calendar.date(byAdding: .day, value: startOffset + i, to: now),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }

            let message = Self.messages[(anchor + i) % Self.messages.count]

            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.interruptionLevel = .active

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(Self.idPrefix)\(i)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error { logger.error("Failed to schedule daily reminder \(i): \(error)") }
            }
        }

        logger.info("Scheduled \(Self.windowDays) daily reminders at \(self.hour):\(self.minute) (startOffset \(startOffset))")
    }

    // MARK: - Copy

    private struct Reminder { let title: String; let body: String }

    /// A pool of clever, funny, inviting prompts. The world is the pantry —
    /// every one nudges the user to point their camera at *something* and cook.
    private static let messages: [Reminder] = [
        Reminder(title: "Your camera's been craving something 📸",
                 body: "That sunset, that sweater, that subway tile — all secretly delicious. Come find out what."),
        Reminder(title: "Chef is tapping the counter 👨‍🍳",
                 body: "A whole world of ingredients out there and you're just… looking at it? Snap something."),
        Reminder(title: "Plot twist: dinner was a photo",
                 body: "Point your lens at literally anything and we'll plate it up. No dishes, we promise."),
        Reminder(title: "Your taste buds called ☎️",
                 body: "They're bored. Photograph something weird today and let us turn it into a feast."),
        Reminder(title: "Reminder: everything is edible (visually)",
                 body: "Your houseplant. That brick wall. Your cat. One tap and it's a tasting menu."),
        Reminder(title: "We saved you a seat at the pass",
                 body: "Today's special is whatever you point your camera at. Come cook with us."),
        Reminder(title: "Hungry eyes? 👀",
                 body: "Turn the prettiest thing you see today into a recipe you'd actually frame."),
        Reminder(title: "The kitchen misses you",
                 body: "Two minutes, one photo, infinite flavor. Your move, gourmet."),
        Reminder(title: "What's for dinner? Ask your camera roll.",
                 body: "Open the app, snap a vibe, and we'll handle the haute cuisine."),
        Reminder(title: "Psst… your next masterpiece is one tap away",
                 body: "That cloud looks like a soufflé. Prove us right."),
        Reminder(title: "Warning: the world looks tastier through this lens",
                 body: "Find something beautiful, ugly, or totally random — we'll make it delicious either way."),
        Reminder(title: "A chef walked into your notifications…",
                 body: "…and said 'photograph that, immediately.' Don't keep them waiting."),
        Reminder(title: "Bored? We turn boredom into béarnaise.",
                 body: "Snap anything. We dare you to make it un-delicious."),
        Reminder(title: "Your daily dose of edible imagination ✨",
                 body: "One photo. One impossibly good recipe. Zero cleanup."),
        Reminder(title: "Caught you scrolling 🍳",
                 body: "Same energy, better snack. Photograph something and let's cook it up instead."),
        Reminder(title: "The pantry is the whole planet today",
                 body: "Pick anything in sight and watch it become a five-star plate."),
    ]
}
