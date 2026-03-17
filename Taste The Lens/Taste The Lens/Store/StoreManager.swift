import Foundation
import StoreKit
import Supabase
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Store")

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false

    static let monthlyProductId = "com.tastethelens.pro.monthly"
    static let annualProductId = "com.tastethelens.pro.annual"

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [
                Self.monthlyProductId,
                Self.annualProductId
            ])
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
            await updateSubscriptionStatus()
            await transaction.finish()

            // Update Supabase tier
            if AuthManager.shared.isAuthenticated,
               let userId = AuthManager.shared.currentUser?.id.uuidString {
                try? await SupabaseManager.shared.client.from("users")
                    .update(["subscription_tier": "pro"])
                    .eq("id", value: userId)
                    .execute()
            }

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
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.monthlyProductId ||
                   transaction.productID == Self.annualProductId {
                    hasPro = true
                }
            }
        }

        isPro = hasPro
        logger.info("Subscription status: isPro=\(hasPro)")
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

    // MARK: - Helpers

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductId }
    }

    var annualProduct: Product? {
        products.first { $0.id == Self.annualProductId }
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
