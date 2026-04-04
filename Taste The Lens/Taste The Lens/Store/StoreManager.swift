import Foundation
import StoreKit
import Supabase
import os

private let logger = makeLogger(category: "Store")

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var hasCheckedStatus = false

    /// Whether the user has an active legacy subscription (detected via StoreKit)
    private(set) var hasActiveLegacySubscription = false

    // MARK: - Product IDs

    // New credit packs (pure credits model)
    static let tastePackId      = "com.tastethelens.credits.taste"       // 10 credits, $1.99
    static let cookPackId       = "com.tastethelens.credits.cook"        // 30 credits, $4.99
    static let feastPackId      = "com.tastethelens.credits.feast"       // 75 credits, $9.99
    static let chefsStashPackId = "com.tastethelens.credits.chefstash"   // 175 credits, $19.99
    static let cellarPackId     = "com.tastethelens.credits.cellar"      // 600 credits, $49.99

    // Auto-refill subscription (convenience, no feature gates)
    static let autoRefillMonthlyId = "com.tastethelens.autorefill.monthly"  // $3.99/mo → 30 credits

    // Legacy credit packs (kept for transaction handling of old purchases)
    static let legacyStarterPackId = "com.tastethelens.credits.starter"
    static let legacyClassicPackId = "com.tastethelens.credits.classic"
    static let legacyPantryPackId  = "com.tastethelens.credits.pantry"

    // Legacy subscriptions (kept for StoreKit entitlement detection)
    static let legacyMonthlyId         = "com.tastethelens.pro.monthly"
    static let legacyAnnualId          = "com.tastethelens.pro.annual"
    static let legacyChefsTableMonthly = "com.tastethelens.chefstable.monthly"
    static let legacyChefsTableAnnual  = "com.tastethelens.chefstable.annual"
    static let legacyAtelierMonthly    = "com.tastethelens.atelier.monthly"

    /// Maps credit pack product IDs to credit amounts (new + legacy)
    static let creditPackAmounts: [String: Int] = [
        // New packs
        tastePackId: 10,
        cookPackId: 30,
        feastPackId: 75,
        chefsStashPackId: 175,
        cellarPackId: 600,
        // Legacy packs (for replayed transactions)
        legacyStarterPackId: 10,
        legacyClassicPackId: 50,
        legacyPantryPackId: 90,
    ]

    /// Product IDs for the new credit packs (used for display in PaywallView)
    static let newCreditPackIds: Set<String> = [
        tastePackId, cookPackId, feastPackId, chefsStashPackId, cellarPackId
    ]

    /// All subscription IDs (legacy + auto-refill)
    private static let subscriptionIds: Set<String> = [
        legacyMonthlyId, legacyAnnualId,
        legacyChefsTableMonthly, legacyChefsTableAnnual, legacyAtelierMonthly,
        autoRefillMonthlyId
    ]

    private static let allProductIds: Set<String> = {
        var ids = newCreditPackIds
        ids.formUnion(subscriptionIds)
        ids.formUnion([legacyStarterPackId, legacyClassicPackId, legacyPantryPackId])
        return ids
    }()

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await checkLegacySubscription() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Accessors

    /// New credit pack products, sorted by price (for PaywallView)
    var creditProducts: [Product] {
        products.filter { Self.newCreditPackIds.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    /// Auto-refill subscription product (if loaded)
    var autoRefillProduct: Product? {
        products.first { $0.id == Self.autoRefillMonthlyId }
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.allProductIds)
            logger.info("Loaded \(self.products.count) products")
        } catch {
            logger.error("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        // Set appAccountToken to the authenticated user's UUID so Apple's
        // App Store Server Notifications webhook can identify which user
        // the transaction belongs to.
        var purchaseOptions: Set<Product.PurchaseOption> = []
        if let userId = AuthManager.shared.currentUser?.id {
            purchaseOptions.insert(.appAccountToken(userId))
        }
        let result = try await product.purchase(options: purchaseOptions)

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            if let creditCount = Self.creditPackAmounts[product.id] {
                // Consumable credit pack
                UsageTracker.shared.addPurchasedCredits(creditCount)
                logger.info("Credit pack purchased: \(creditCount) credits from \(product.id)")
            } else if product.id == Self.autoRefillMonthlyId {
                // Auto-refill subscription — credits are granted by webhook on renewal.
                // Mark as paid user for feature unlock.
                EntitlementManager.shared.hasEverPurchased = true
                logger.info("Auto-refill subscription purchased")
            } else if Self.subscriptionIds.contains(product.id) {
                // Legacy subscription (shouldn't happen on new app, but handle gracefully)
                EntitlementManager.shared.hasEverPurchased = true
                logger.info("Legacy subscription purchased: \(product.id)")
            }

            await transaction.finish()
            logger.info("Purchase successful: \(product.id)")
            return true

        case .userCancelled:
            return false

        case .pending:
            logger.info("Purchase pending")
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkLegacySubscription()
        // Re-sync credits from server in case webhooks granted credits
        await UsageTracker.shared.syncCreditsFromServer()
    }

    // MARK: - Legacy Subscription Detection

    /// Check if the user has any active legacy subscription via StoreKit.
    /// This is used to show "Manage in Apple Settings" in SettingsView.
    func checkLegacySubscription() async {
        var foundLegacy = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if Self.subscriptionIds.contains(transaction.productID) {
                    foundLegacy = true
                    // User has an active subscription → they've paid before
                    EntitlementManager.shared.hasEverPurchased = true
                }
            }
        }

        hasActiveLegacySubscription = foundLegacy
        hasCheckedStatus = true
        logger.info("Legacy subscription check: \(foundLegacy ? "active" : "none")")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Handle replayed consumable transactions (e.g. app crashed before finish)
                    if Self.creditPackAmounts[transaction.productID] != nil {
                        // The server is authoritative, so sync to reconcile
                        await UsageTracker.shared.syncCreditsFromServer()
                        logger.info("Replayed consumable transaction: \(transaction.productID)")
                    }
                    // Re-check for legacy/auto-refill subscriptions
                    await self.checkLegacySubscription()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed."
        }
    }
}
