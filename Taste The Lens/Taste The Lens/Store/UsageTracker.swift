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

    /// Guard to prevent `updateFromServer` from overwriting an in-flight `addPurchasedCredits` sync
    private var isSyncingCredits = false

    private init() {
        // Initialize cached guest usage properties from UserDefaults
        _guestUsageCount = UserDefaults.standard.integer(forKey: "guestUsageCount")
        let interval = UserDefaults.standard.double(forKey: "guestUsageResetDate")
        if interval == 0 {
            let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            let startOfNextMonth = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!)
            UserDefaults.standard.set(startOfNextMonth.timeIntervalSince1970, forKey: "guestUsageResetDate")
            _guestUsageResetDate = startOfNextMonth
        } else {
            _guestUsageResetDate = Date(timeIntervalSince1970: interval)
        }

        resetIfNewMonth()
    }

    // MARK: - Guest Usage (local, cached to avoid repeated disk access)

    private var _guestUsageCount: Int
    private var guestUsageCount: Int {
        get { _guestUsageCount }
        set {
            _guestUsageCount = newValue
            UserDefaults.standard.set(newValue, forKey: "guestUsageCount")
        }
    }

    private var _guestUsageResetDate: Date
    private var guestUsageResetDate: Date {
        get { _guestUsageResetDate }
        set {
            _guestUsageResetDate = newValue
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "guestUsageResetDate")
        }
    }

    // MARK: - Credit Pool

    /// Credits purchased via credit packs — never expire.
    /// Welcome credits (5 on signup) are also stored here.
    private(set) var purchasedCredits: Int = UserDefaults.standard.integer(forKey: "purchasedCredits") {
        didSet { UserDefaults.standard.set(purchasedCredits, forKey: "purchasedCredits") }
    }

    // MARK: - Public API

    var totalAvailableCredits: Int {
        purchasedCredits
    }

    var canGenerate: Bool {
        // Don't block users before initial status is confirmed
        if !StoreManager.shared.hasCheckedStatus { return true }

        // Has purchased credits OR has remaining free generations (guest)
        return purchasedCredits > 0 || remainingFreeGenerations > 0
    }

    var remainingFreeGenerations: Int {
        // Free generation tracking is only for unauthenticated guests.
        // Authenticated users get welcome credits as purchased_credits.
        guard !AuthManager.shared.isAuthenticated else {
            return 0
        }
        return max(0, Self.freeLimit - guestUsageCount)
    }

    var remainingGenerations: Int {
        purchasedCredits + remainingFreeGenerations
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
        if purchasedCredits > 0 {
            return "\(purchasedCredits) credits"
        } else if !AuthManager.shared.isAuthenticated {
            return "\(remainingFreeGenerations) of \(Self.freeLimit) free tastings"
        } else {
            return "0 credits"
        }
    }

    // MARK: - Credit Operations

    /// Add purchased credits (from credit pack purchase)
    func addPurchasedCredits(_ count: Int) {
        // Optimistic local update for immediate UI feedback
        purchasedCredits += count
        EntitlementManager.shared.hasEverPurchased = true
        logger.info("Added \(count) purchased credits — total: \(self.purchasedCredits)")

        if AuthManager.shared.isAuthenticated {
            isSyncingCredits = true
            Task {
                defer { isSyncingCredits = false }
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

    // MARK: - Server Credit Updates

    /// Update local credit cache from server-returned balances (called after analyze-image response)
    func updateFromServer(_ balance: CreditBalance) {
        // Don't overwrite purchased credits if a local purchase is still syncing to the server
        if isSyncingCredits {
            logger.info("Skipping purchased credit overwrite — credit sync in flight")
        } else {
            purchasedCredits = balance.purchased_credits
        }
        if !AuthManager.shared.isAuthenticated {
            cachedServerCount = balance.free_usage_count
            guestUsageCount = balance.free_usage_count
        }
        logger.info("Credits updated from server — purchased: \(balance.purchased_credits), free: \(balance.free_usage_count)")
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
            if (error as? URLError)?.code == .cancelled || error is CancellationError { return }
            logger.warning("Failed to sync usage from server: \(error)")
        }
    }

    /// Sync credit balances from server.
    func syncCreditsFromServer() async {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            struct CreditResponse: Decodable {
                let purchased_credits: Int
                let subscription_credits: Int  // Legacy — always 0 post-migration
                let rollover_credits: Int      // Legacy — always 0 post-migration
                let subscription_tier: String?
                let has_ever_purchased: Bool?
            }

            let response = try await SupabaseManager.shared.client
                .rpc("get_credits", params: ["user_id_param": userId])
                .execute()

            if let credits = try? JSONDecoder().decode(CreditResponse.self, from: response.data) {
                purchasedCredits = credits.purchased_credits

                // Sync has_ever_purchased from server
                if let everPurchased = credits.has_ever_purchased, everPurchased {
                    EntitlementManager.shared.hasEverPurchased = true
                }

                logger.info("Credits synced — purchased: \(credits.purchased_credits), hasEverPurchased: \(credits.has_ever_purchased ?? false)")
            }
        } catch {
            if (error as? URLError)?.code == .cancelled || error is CancellationError { return }
            logger.warning("Failed to sync credits from server: \(error)")
        }
    }

    // MARK: - Welcome Credits

    /// Call the grant_welcome_credits RPC to grant welcome credits for new users.
    /// Idempotent — safe to call multiple times; the server checks `welcome_credits_granted`.
    func claimWelcomeCreditsIfNeeded() async {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id else { return }

        struct WelcomeResponse: Decodable {
            let granted: Bool
            let credits_added: Int
        }

        do {
            let response = try await SupabaseManager.shared.client
                .rpc("grant_welcome_credits", params: ["p_user_id": userId.uuidString])
                .execute()

            if let result = try? JSONDecoder().decode(WelcomeResponse.self, from: response.data),
               result.granted {
                purchasedCredits += result.credits_added
                logger.info("Welcome credits granted: \(result.credits_added)")
            }
        } catch {
            logger.warning("Failed to claim welcome credits: \(error)")
        }
    }

    // MARK: - Sign-Out Reset

    /// Clear all user-specific state when signing out or deleting account.
    /// This prevents credit/usage data from one account leaking to another.
    func resetForSignOut() {
        purchasedCredits = 0
        cachedServerCount = nil
        guestUsageCount = 0
        EntitlementManager.shared.hasEverPurchased = false
        UserDefaults.standard.set(false, forKey: "hasCompletedCreditMigrationV3")
        logger.info("UsageTracker reset for sign-out")
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

    // MARK: - One-Time Credit Migration

    private static let migrationKey = "hasCompletedCreditMigrationV3"

    /// Reconcile local credit values with server on first launch after update.
    /// Uses MAX(server, client) for purchased credits to avoid penalizing legitimate users.
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
                    "p_client_subscription": "0",
                    "p_client_rollover": "0"
                ])
                .execute()

            if let result = try? JSONDecoder().decode(ReconcileResponse.self, from: response.data),
               result.success {
                purchasedCredits = result.purchased_credits ?? purchasedCredits
                if let freeCount = result.free_usage_count {
                    cachedServerCount = freeCount
                }
                logger.info("Credit reconciliation complete — purchased: \(self.purchasedCredits)")
            }

            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        } catch {
            logger.warning("Credit reconciliation failed: \(error)")
        }
    }
}
