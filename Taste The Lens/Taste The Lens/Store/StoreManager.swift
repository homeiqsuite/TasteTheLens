import Foundation
import StoreKit
import Supabase
import os

private let logger = makeLogger(category: "Store")

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private(set) var products: [Product] = []
    private(set) var currentTier: SubscriptionTier = .free
    private(set) var isLoading = false
    private(set) var hasCheckedStatus = false

    // MARK: - Product IDs

    // Legacy (kept for migration)
    static let legacyMonthlyId = "com.tastethelens.pro.monthly"
    static let legacyAnnualId = "com.tastethelens.pro.annual"

    // Credit packs (consumable)
    static let starterPackId = "com.tastethelens.credits.starter"   // 10 credits, $1.99
    static let classicPackId = "com.tastethelens.credits.classic"   // 50 credits, $8.99
    static let pantryPackId  = "com.tastethelens.credits.pantry"    // 100 credits, $14.99

    // Subscriptions (auto-renewable)
    static let chefsTableMonthlyId = "com.tastethelens.chefstable.monthly"  // $9.99/mo
    static let atelierMonthlyId    = "com.tastethelens.atelier.monthly"     // $49.99/mo

    /// Maps credit pack product IDs to credit amounts
    static let creditPackAmounts: [String: Int] = [
        starterPackId: 10,
        classicPackId: 50,
        pantryPackId: 100
    ]

    private static let allProductIds: Set<String> = [
        legacyMonthlyId, legacyAnnualId,
        starterPackId, classicPackId, pantryPackId,
        chefsTableMonthlyId, atelierMonthlyId
    ]

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Backward Compatibility

    /// Backward-compatible pro check — true if user has any subscription
    var isPro: Bool {
        currentTier != .free
    }

    // MARK: - Product Accessors

    var creditProducts: [Product] {
        products.filter { Self.creditPackAmounts.keys.contains($0.id) }
            .sorted { $0.price < $1.price }
    }

    var subscriptionProducts: [Product] {
        let subIds: Set<String> = [
            Self.chefsTableMonthlyId, Self.atelierMonthlyId,
            Self.legacyMonthlyId, Self.legacyAnnualId
        ]
        return products.filter { subIds.contains($0.id) }
    }

    var chefsTableProduct: Product? {
        products.first { $0.id == Self.chefsTableMonthlyId }
    }

    var atelierProduct: Product? {
        products.first { $0.id == Self.atelierMonthlyId }
    }

    // Legacy accessors (for existing code that may reference these)
    var monthlyProduct: Product? {
        products.first { $0.id == Self.chefsTableMonthlyId }
            ?? products.first { $0.id == Self.legacyMonthlyId }
    }

    var annualProduct: Product? {
        products.first { $0.id == Self.legacyAnnualId }
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
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)

            if let creditCount = Self.creditPackAmounts[product.id] {
                // Consumable credit pack
                UsageTracker.shared.addPurchasedCredits(creditCount)
                logger.info("Credit pack purchased: \(creditCount) credits from \(product.id)")
            } else {
                // Subscription
                await updateSubscriptionStatus()

                // Update Supabase tier via server-side RPC (validates auth.uid())
                if AuthManager.shared.isAuthenticated {
                    let tierValue = tierForProductId(product.id).rawValue
                    try? await SupabaseManager.shared.client
                        .rpc("update_subscription_tier", params: ["tier_value": tierValue])
                        .execute()
                }

                // Refresh subscription credits
                let tier = tierForProductId(product.id)
                if tier != .free {
                    UsageTracker.shared.refreshSubscriptionCredits(tier: tier)
                }
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
        await updateSubscriptionStatus()
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        var detectedTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let tier = tierForProductId(transaction.productID)
                if tier > detectedTier {
                    detectedTier = tier
                }
            }
        }

        // Also check Supabase
        let supabaseTier = await checkSupabaseTier()
        if supabaseTier > detectedTier {
            detectedTier = supabaseTier
        }

        currentTier = detectedTier
        hasCheckedStatus = true

        // Clear subscription credits if tier dropped to free
        if detectedTier == .free {
            UsageTracker.shared.clearSubscriptionCredits()
        }

        logger.info("Subscription status: tier=\(detectedTier.displayName)")
    }

    private func checkSupabaseTier() async -> SubscriptionTier {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id.uuidString else { return .free }

        do {
            struct UserTier: Decodable { let subscription_tier: String? }
            let response = try await SupabaseManager.shared.client
                .from("users")
                .select("subscription_tier")
                .eq("id", value: userId)
                .single()
                .execute()
            let user = try JSONDecoder().decode(UserTier.self, from: response.data)

            switch user.subscription_tier {
            case "pro", "chefsTable": return .chefsTable
            case "atelier": return .atelier
            default: return .free
            }
        } catch {
            logger.warning("Failed to check Supabase tier: \(error)")
            return .free
        }
    }

    // MARK: - Tier Mapping

    private func tierForProductId(_ productId: String) -> SubscriptionTier {
        switch productId {
        case Self.chefsTableMonthlyId, Self.legacyMonthlyId, Self.legacyAnnualId:
            return .chefsTable
        case Self.atelierMonthlyId:
            return .atelier
        default:
            return .free
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updateSubscriptionStatus()
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
