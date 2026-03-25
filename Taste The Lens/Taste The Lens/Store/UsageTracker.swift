import Foundation
import Supabase
import os

private let logger = makeLogger(category: "Usage")

@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    private static let freeLimit = 5

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
    }

    /// Clear subscription credits (when subscription lapses)
    func clearSubscriptionCredits() {
        subscriptionCredits = 0
        rolledOverCredits = 0
        subscriptionCreditResetDate = nil
        logger.info("Subscription credits cleared")
    }

    // MARK: - Usage Increment

    /// Deduct one credit/generation. Order: free gens → rollover → subscription → purchased
    func incrementUsage() {
        if EntitlementManager.shared.isSubscriber {
            deductSubscriberCredit()
        } else if remainingFreeGenerations > 0 {
            deductFreeGeneration()
        } else if purchasedCredits > 0 {
            purchasedCredits -= 1
            logger.info("Deducted 1 purchased credit — remaining: \(self.purchasedCredits)")
        }
    }

    private func deductSubscriberCredit() {
        if rolledOverCredits > 0 {
            rolledOverCredits -= 1
            logger.info("Deducted 1 rollover credit — remaining: \(self.rolledOverCredits)")
        } else if subscriptionCredits > 0 {
            subscriptionCredits -= 1
            logger.info("Deducted 1 subscription credit — remaining: \(self.subscriptionCredits)")
        } else if purchasedCredits > 0 {
            purchasedCredits -= 1
            logger.info("Deducted 1 purchased credit — remaining: \(self.purchasedCredits)")
        }
    }

    private func deductFreeGeneration() {
        guestUsageCount += 1
        if let cached = cachedServerCount {
            cachedServerCount = cached + 1
        }
        logger.info("Free generation used — \(self.usageCount)/\(Self.freeLimit)")

        if AuthManager.shared.isAuthenticated {
            Task {
                do {
                    guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
                    try await SupabaseManager.shared.client
                        .rpc("increment_usage", params: ["user_id_param": userId])
                        .execute()
                    logger.info("Remote usage updated successfully")
                } catch {
                    logger.warning("Remote usage update failed: \(error)")
                }
            }
        }
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
}
