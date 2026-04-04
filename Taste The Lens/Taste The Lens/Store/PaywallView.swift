import SwiftUI
import StoreKit
import os

private let logger = makeLogger(category: "Paywall")

// MARK: - Paywall Context

enum PaywallContext {
    case outOfGenerations
    case featureGated(Feature)
    case topUp

    var title: String {
        switch self {
        case .outOfGenerations:
            return UsageTracker.shared.canGenerate ? "Get More Credits" : "You're out of credits"
        case .featureGated:
            return "Unlock All Features"
        case .topUp:
            return "Get More Credits"
        }
    }

    var subtitle: String {
        switch self {
        case .outOfGenerations:
            return "Buy credits to generate more recipes"
        case .featureGated:
            return "Any credit pack purchase unlocks all premium features"
        case .topUp:
            return "Add credits to your balance"
        }
    }

    var icon: String {
        switch self {
        case .outOfGenerations: return "sparkles"
        case .featureGated: return "lock.open.fill"
        case .topUp: return "plus.circle"
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var purchasingProductId: String?
    @State private var errorMessage: String?

    private let store = StoreManager.shared
    private let usage = UsageTracker.shared

    init(context: PaywallContext = .outOfGenerations) {
        self.context = context
    }

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 32)

                    headerSection
                    creditBalanceBadge
                    unlockBanner
                    creditPacksSection
                    autoRefillSection
                    errorSection
                    footerButtons

                    Spacer().frame(height: 24)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: context.icon)
                .font(.system(size: 40))
                .foregroundStyle(Theme.gold)

            Text(context.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)
                .multilineTextAlignment(.center)

            Text(context.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextTertiary)
                .multilineTextAlignment(.center)

            // Usage info for out-of-generations context
            if case .outOfGenerations = context {
                Text(usage.creditBalanceDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextHint)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Credit Balance Badge

    @ViewBuilder
    private var creditBalanceBadge: some View {
        let totalCredits = usage.totalAvailableCredits + usage.remainingFreeGenerations
        if totalCredits > 0 {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.visual)
                Text("\(totalCredits) credits available")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.darkTextPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.visual.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.visual.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Unlock Banner

    @ViewBuilder
    private var unlockBanner: some View {
        if !EntitlementManager.shared.hasEverPurchased {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gold)
                Text("Any purchase unlocks all premium features")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.gold.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.gold.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Credit Packs

    private var creditPacksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Credit Packs")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            if store.creditProducts.isEmpty && store.isLoading {
                loadingPlaceholder
            }

            ForEach(store.creditProducts) { product in
                creditPackButton(product: product)
            }
        }
        .padding(.horizontal, 24)
    }

    private func creditPackButton(product: Product) -> some View {
        let creditCount = StoreManager.creditPackAmounts[product.id] ?? 0
        let isThisPurchasing = purchasingProductId == product.id
        let isBestValue = product.id == StoreManager.chefsStashPackId
        let perCredit = creditCount > 0
            ? String(format: "$%.2f/credit", NSDecimalNumber(decimal: product.price).doubleValue / Double(creditCount))
            : ""

        return Button {
            purchaseProduct(product)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(creditCount) credits")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.darkTextPrimary)

                        if isBestValue {
                            Text("Best Value")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.gold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Text(packLabel(for: product.id))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.darkTextTertiary)
                        Text(perCredit)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.darkTextHint)
                    }
                }

                Spacer()

                if isThisPurchasing {
                    ProgressView().tint(Theme.gold)
                } else {
                    Text(product.displayPrice)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(14)
            .background(Theme.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isBestValue ? Theme.gold.opacity(0.4) : Theme.darkStroke,
                            lineWidth: isBestValue ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private func packLabel(for productId: String) -> String {
        switch productId {
        case StoreManager.tastePackId:      return "Taste"
        case StoreManager.cookPackId:       return "Cook"
        case StoreManager.feastPackId:      return "Feast"
        case StoreManager.chefsStashPackId: return "Chef's Stash"
        case StoreManager.cellarPackId:     return "Cellar"
        default: return ""
        }
    }

    // MARK: - Auto-Refill

    @ViewBuilder
    private var autoRefillSection: some View {
        if let autoRefill = store.autoRefillProduct {
            VStack(alignment: .leading, spacing: 14) {
                Text("Never Run Out")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                let isThisPurchasing = purchasingProductId == autoRefill.id

                Button {
                    purchaseProduct(autoRefill)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Refill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.darkTextPrimary)
                            Text("30 credits loaded every month. Cancel anytime.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.darkTextTertiary)
                        }

                        Spacer()

                        if isThisPurchasing {
                            ProgressView().tint(Theme.gold)
                        } else {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(autoRefill.displayPrice)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.gold)
                                Text("/month")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.darkTextHint)
                            }
                        }
                    }
                    .padding(14)
                    .background(Theme.darkSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.darkStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Text(error)
                .font(.system(size: 13))
                .foregroundStyle(.red.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await store.restorePurchases()
                    if EntitlementManager.shared.hasEverPurchased { dismiss() }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextTertiary)
            }

            Button { dismiss() } label: {
                Text("Not now")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.darkTextHint)
            }
        }
    }

    // MARK: - Helpers

    private var loadingPlaceholder: some View {
        Text("Loading pricing...")
            .font(.system(size: 14))
            .foregroundStyle(Theme.darkTextTertiary)
            .padding(.vertical, 12)
    }

    private func purchaseProduct(_ product: Product) {
        Task {
            isPurchasing = true
            purchasingProductId = product.id
            errorMessage = nil
            do {
                let success = try await store.purchase(product)
                if success {
                    HapticManager.success()
                    try? await Task.sleep(for: .milliseconds(300))
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                logger.error("Purchase failed: \(error)")
            }
            isPurchasing = false
            purchasingProductId = nil
        }
    }
}
