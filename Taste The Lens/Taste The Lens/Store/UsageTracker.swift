import Foundation
import Supabase
import os

private let logger = makeLogger(category: "Usage")

@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    private static var freeLimit: Int { RemoteConfigManager.shared.freeGenerationLimit }

    /// Server-side usage count, cached locally for offline support
    private var cachedServerCount: Int?

    private init() {
        resetIfNewMonth()
        resetSubscriptionCreditsIfNeeded()
    }

    // MARK: - Guest Usage (local)

    private var guestUsageCount: Int {
        get { UserDefaults.standard.integer(forKey: "guestUsageCount") }
        set { UserDefaults.standard.set(newValue, forKey: "guestUsageCount") }
    }

    private var guestUsageResetDate: Date {
        get {
            let interval = UserDefaults.standard.double(forKey: "guestUsageResetDate")
            if interval == 0 {
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
                let startOfNextMonth = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!)
                UserDefaults.standard.set(startOfNextMonth.timeIntervalSince1970, forKey: "guestUsageResetDate")
                return startOfNextMonth
            }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "guestUsageResetDate")
        }
    }

    // MARK: - Credit Pools

    /// Credits purchased via credit packs — never expire
    private(set) var purchasedCredits: Int = UserDefaults.standard.integer(forKey: "purchasedCredits") {
        didSet { UserDefaults.standard.set(purchasedCredits, forKey: "purchasedCredits") }
    }

    /// Current month's subscription credits
    private(set) var subscriptionCredits: Int = UserDefaults.standard.integer(forKey: "subscriptionCredits") {
        didSet { UserDefaults.standard.set(subscriptionCredits, forKey: "subscriptionCredits") }
    }

    /// Unused subscription credits rolled over from last month (max 1 month)
    private(set) var rolledOverCredits: Int = UserDefaults.standard.integer(forKey: "rolledOverCredits") {
        didSet { UserDefaults.standard.set(rolledOverCredits, forKey: "rolledOverCredits") }
    }

    // MARK: - Purchase Tracking (for upgrade nudge)

    /// Number of credit pack purchases made (for subscription upgrade nudge)
    private(set) var creditPackPurchaseCount: Int = UserDefaults.standard.integer(forKey: "creditPackPurchaseCount") {
        didSet { UserDefaults.standard.set(creditPackPurchaseCount, forKey: "creditPackPurchaseCount") }
    }

    /// Cumulative spend on credit packs (for upgrade nudge messaging)
    private(set) var creditPackTotalSpend: Double = UserDefaults.standard.double(forKey: "creditPackTotalSpend") {
        didSet { UserDefaults.standard.set(creditPackTotalSpend, forKey: "creditPackTotalSpend") }
    }

    /// Whether the user has purchased a Classic or higher credit pack (unlocks clean exports)
    var hasPurchasedClassicOrHigher: Bool {
        get { UserDefaults.standard.bool(forKey: "hasPurchasedClassicOrHigher") }
        set { UserDefaults.standard.set(newValue, forKey: "hasPurchasedClassicOrHigher") }
    }

    /// Whether the user has dismissed the subscription nudge
    var hasSeenSubscriptionNudge: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenSubscriptionNudge") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenSubscriptionNudge") }
    }

    /// Track a credit pack purchase for nudge logic
    func trackCreditPackPurchase(price: Decimal) {
        creditPackPurchaseCount += 1
        creditPackTotalSpend += NSDecimalNumber(decimal: price).doubleValue
        logger.info("Credit pack purchase tracked: count=\(self.creditPackPurchaseCount), total=\(self.creditPackTotalSpend)")
    }

    /// Whether the subscription upgrade nudge should be shown
    var shouldShowSubscriptionNudge: Bool {
        creditPackPurchaseCount >= 3
            && !EntitlementManager.shared.isSubscriber
            && !hasSeenSubscriptionNudge
    }

    // MARK: - Subscription Credit Reset

    private var subscriptionCreditResetDate: Date? {
        get {
            let interval = UserDefaults.standard.double(forKey: "subscriptionCreditResetDate")
            return interval == 0 ? nil : Date(timeIntervalSince1970: interval)
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "subscriptionCreditResetDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "subscriptionCreditResetDate")
            }
        }
    }

    /// Total credits available across all pools
    var totalAvailableCredits: Int {
        purchasedCredits + subscriptionCredits + rolledOverCredits
    }

    /// The date when subscription credits reset (for notification scheduling)
    var creditResetDate: Date? { subscriptionCreditResetDate }

    /// Days until subscription credits refresh
    var daysUntilCreditRefresh: Int? {
        guard EntitlementManager.shared.isSubscriber,
              let resetDate = subscriptionCreditResetDate else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: resetDate).day ?? 0)
    }

    // MARK: - Public API

    var isPro: Bool {
        EntitlementManager.shared.isSubscriber
    }

    var canGenerate: Bool {
        // Don't block users before subscription status is confirmed
        if !StoreManager.shared.hasCheckedStatus { return true }

        if EntitlementManager.shared.isSubscriber {
            return totalAvailableCredits > 0
        }

        // Free tier: check free gens remaining OR purchased credits
        return remainingFreeGenerations > 0 || purchasedCredits > 0
    }

    var remainingFreeGenerations: Int {
        if EntitlementManager.shared.isSubscriber { return 0 } // Subscribers use credits
        if AuthManager.shared.isAuthenticated, let serverCount = cachedServerCount {
            return max(0, Self.freeLimit - serverCount)
        }
        return max(0, Self.freeLimit - guestUsageCount)
    }

    var remainingGenerations: Int {
        if EntitlementManager.shared.isSubscriber {
            return totalAvailableCredits
        }
        return remainingFreeGenerations + purchasedCredits
    }

    var usageCount: Int {
        if AuthManager.shared.isAuthenticated, let serverCount = cachedServerCount {
            return serverCount
        }
        return guestUsageCount
    }

    var usageLimit: Int {
        Self.freeLimit
    }

    /// Display-friendly credit balance string
    var creditBalanceDescription: String {
        if EntitlementManager.shared.isSubscriber {
            var parts: [String] = []
            if rolledOverCredits > 0 { parts.append("\(rolledOverCredits) rollover") }
            if subscriptionCredits > 0 { parts.append("\(subscriptionCredits) monthly") }
            if purchasedCredits > 0 { parts.append("\(purchasedCredits) purchased") }
            return parts.joined(separator: " + ")
        } else if purchasedCredits > 0 {
            return "\(purchasedCredits) purchased credits"
        } else {
            return "\(remainingFreeGenerations) of \(Self.freeLimit) free tastings"
        }
    }

    // MARK: - Credit Operations

    /// Add purchased credits (from credit pack purchase)
    func addPurchasedCredits(_ count: Int) {
        // Optimistic local update for immediate UI feedback
        purchasedCredits += count
        logger.info("Added \(count) purchased credits — total: \(self.purchasedCredits)")

        if AuthManager.shared.isAuthenticated {
            Task {
                do {
                    guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
                    let params: [String: String] = [
                        "user_id_param": userId,
                        "credit_count": String(count)
                    ]
                    try await SupabaseManager.shared.client
                        .rpc("add_purchased_credits", params: params)
                        .execute()
                    logger.info("Remote purchased credits updated")
                    // Sync back from server to ensure local cache matches
                    await syncCreditsFromServer()
                } catch {
                    logger.warning("Remote credit update failed: \(error)")
                }
            }
        }
    }

    /// Refresh subscription credits for a new billing period
    func refreshSubscriptionCredits(tier: SubscriptionTier) {
        // Roll over unused current credits (max 1 month)
        rolledOverCredits = subscriptionCredits
        subscriptionCredits = tier.monthlyCredits

        // Set next reset date
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        subscriptionCreditResetDate = Calendar.current.startOfDay(
            for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!
        )

        logger.info("Subscription credits refreshed: \(tier.monthlyCredits) new, \(self.rolledOverCredits) rolled over")

        Task { @MainActor in
            CreditExpiryNotificationService.shared.scheduleExpiryNotificationIfNeeded()
        }
    }

    /// Clear subscription credits (when subscription lapses)
    func clearSubscriptionCredits() {
        subscriptionCredits = 0
        rolledOverCredits = 0
        subscriptionCreditResetDate = nil
        logger.info("Subscription credits cleared")

        Task { @MainActor in
            CreditExpiryNotificationService.shared.cancelNotification()
        }
    }

    // MARK: - Server Credit Updates

    /// Update local credit cache from server-returned balances (called after analyze-image response)
    func updateFromServer(_ balance: CreditBalance) {
        purchasedCredits = balance.purchased_credits
        subscriptionCredits = balance.subscription_credits
        rolledOverCredits = balance.rollover_credits
        if !EntitlementManager.shared.isSubscriber {
            cachedServerCount = balance.free_usage_count
            guestUsageCount = balance.free_usage_count
        }
        logger.info("Credits updated from server — purchased: \(balance.purchased_credits), sub: \(balance.subscription_credits), rollover: \(balance.rollover_credits), free: \(balance.free_usage_count)")
    }

    /// Increment guest usage count locally (for unauthenticated users only, since server can't track them)
    func incrementGuestUsage() {
        guard !AuthManager.shared.isAuthenticated else { return }
        guestUsageCount += 1
        logger.info("Guest generation used — \(self.guestUsageCount)/\(Self.freeLimit)")
    }

    // MARK: - Server Sync

    /// Fetch server-side usage count on app launch (for authenticated users)
    func syncUsageFromServer() async {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            let response = try await SupabaseManager.shared.client
                .rpc("get_usage", params: ["user_id_param": userId])
                .execute()

            struct UsageResponse: Decodable {
                let count: Int
            }

            if let usage = try? JSONDecoder().decode(UsageResponse.self, from: response.data) {
                cachedServerCount = usage.count
                logger.info("Server usage synced: \(usage.count)/\(Self.freeLimit)")
            }
        } catch {
            logger.warning("Failed to sync usage from server: \(error)")
        }
    }

    /// Sync credit balances from server
    func syncCreditsFromServer() async {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            struct CreditResponse: Decodable {
                let purchased_credits: Int
                let subscription_credits: Int
                let rollover_credits: Int
            }

            let response = try await SupabaseManager.shared.client
                .rpc("get_credits", params: ["user_id_param": userId])
                .execute()

            if let credits = try? JSONDecoder().decode(CreditResponse.self, from: response.data) {
                purchasedCredits = credits.purchased_credits
                subscriptionCredits = credits.subscription_credits
                rolledOverCredits = credits.rollover_credits
                logger.info("Credits synced — purchased: \(credits.purchased_credits), sub: \(credits.subscription_credits), rollover: \(credits.rollover_credits)")
            }
        } catch {
            logger.warning("Failed to sync credits from server: \(error)")
        }
    }

    // MARK: - Signup Bonus

    /// Call the handle-signup edge function to grant bonus credits for new users.
    /// Idempotent — safe to call multiple times; the server checks `signup_bonus_granted`.
    func claimSignupBonusIfNeeded() async {
        guard AuthManager.shared.isAuthenticated else { return }

        struct BonusResponse: Decodable {
            let bonus_granted: Bool
            let credits_added: Int
        }

        do {
            let bonus: BonusResponse = try await SupabaseManager.shared.client.functions
                .invoke("handle-signup")
            if bonus.bonus_granted {
                purchasedCredits += bonus.credits_added
                logger.info("Signup bonus claimed: \(bonus.credits_added) credits")
            }
        } catch {
            logger.warning("Failed to claim signup bonus: \(error)")
        }
    }

    // MARK: - Reset

    private func resetIfNewMonth() {
        if Date() >= guestUsageResetDate {
            guestUsageCount = 0
            cachedServerCount = nil
            let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            guestUsageResetDate = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!)
            logger.info("Monthly usage reset")
        }
    }

    private func resetSubscriptionCreditsIfNeeded() {
        guard let resetDate = subscriptionCreditResetDate,
              Date() >= resetDate else { return }

        let tier = StoreManager.shared.currentTier
        if tier != .free {
            refreshSubscriptionCredits(tier: tier)
        } else {
            clearSubscriptionCredits()
        }
    }

    // MARK: - One-Time Credit Migration

    private static let migrationKey = "hasCompletedCreditMigrationV2"

    /// Reconcile local credit values with server on first launch after update.
    /// Uses MAX(server, client) for each pool to avoid penalizing legitimate users.
    func reconcileCreditsIfNeeded() async {
        guard AuthManager.shared.isAuthenticated,
              !UserDefaults.standard.bool(forKey: Self.migrationKey),
              let userId = AuthManager.shared.currentUser?.id else { return }

        struct ReconcileResponse: Decodable {
            let success: Bool
            let purchased_credits: Int?
            let subscription_credits: Int?
            let rollover_credits: Int?
            let free_usage_count: Int?
        }

        do {
            let response = try await SupabaseManager.shared.client
                .rpc("reconcile_credits", params: [
                    "p_user_id": userId.uuidString,
                    "p_client_purchased": String(purchasedCredits),
                    "p_client_subscription": String(subscriptionCredits),
                    "p_client_rollover": String(rolledOverCredits)
                ])
                .execute()

            if let result = try? JSONDecoder().decode(ReconcileResponse.self, from: response.data),
               result.success {
                purchasedCredits = result.purchased_credits ?? purchasedCredits
                subscriptionCredits = result.subscription_credits ?? subscriptionCredits
                rolledOverCredits = result.rollover_credits ?? rolledOverCredits
                if let freeCount = result.free_usage_count {
                    cachedServerCount = freeCount
                }
                logger.info("Credit reconciliation complete — purchased: \(self.purchasedCredits), sub: \(self.subscriptionCredits), rollover: \(self.rolledOverCredits)")
            }

            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        } catch {
            logger.warning("Credit reconciliation failed: \(error)")
        }
    }
}
