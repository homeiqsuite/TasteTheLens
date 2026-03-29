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
            return "You've used all your tastings"
        case .featureGated(let feature):
            switch feature {
            case .chefPersonalities: return "Unlock All Chefs"
            case .reimagination: return "Unlock Reimagination"
            case .cloudSync: return "Unlock Cloud Sync"
            case .cleanExport: return "Unlock Clean Exports"
            case .unlimitedSaves: return "Unlock Unlimited Saves"
            case .fullDashboard: return "Unlock Full Dashboard"
            case .fullTastingMenus: return "Unlock Tasting Menus"
            case .fullChallenges: return "Unlock Challenges"
            case .bulkExport: return "Unlock Bulk Export"
            default: return "Upgrade to Unlock"
            }
        case .topUp:
            return "Get More Credits"
        }
    }

    var subtitle: String {
        switch self {
        case .outOfGenerations:
            return "Buy credits or subscribe for more"
        case .featureGated:
            return "Subscribe to Chef's Table for premium features"
        case .topUp:
            return "Add credits to your balance"
        }
    }

    var icon: String {
        switch self {
        case .outOfGenerations: return "sparkles"
        case .featureGated: return "lock.fill"
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
    @State private var showSubscriptionNudge = false
    @State private var showAnnualBilling = false

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
                    creditPacksSection
                    subscriptionSection
                    errorSection
                    footerButtons

                    Spacer().frame(height: 24)
                }
            }
            .sheet(isPresented: $showSubscriptionNudge) {
                SubscriptionNudgeSheet(
                    totalSpend: UsageTracker.shared.creditPackTotalSpend,
                    onViewSubscription: {
                        UsageTracker.shared.hasSeenSubscriptionNudge = true
                        showSubscriptionNudge = false
                        // Stay on paywall so user can see subscription options
                    },
                    onDismiss: {
                        UsageTracker.shared.hasSeenSubscriptionNudge = true
                        showSubscriptionNudge = false
                        dismiss()
                    }
                )
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
        if usage.totalAvailableCredits > 0 || usage.purchasedCredits > 0 {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.visual)
                Text("\(usage.totalAvailableCredits + usage.remainingFreeGenerations) credits available")
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

    // MARK: - Credit Packs

    private var creditPacksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Credit Packs")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if EntitlementManager.shared.isSubscriber {
                    Text("10% subscriber discount")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.gold.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

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

        return Button {
            purchaseProduct(product)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(creditCount) credits")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text(packLabel(for: product.id))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.darkTextTertiary)
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
                    .stroke(Theme.darkStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private func packLabel(for productId: String) -> String {
        switch productId {
        case StoreManager.starterPackId: return "Starter Pack"
        case StoreManager.classicPackId: return "Classic Pack"
        case StoreManager.pantryPackId: return "Pantry Pack"
        default: return ""
        }
    }

    // MARK: - Subscriptions

    @ViewBuilder
    private var subscriptionSection: some View {
        // Don't show subscriptions for top-up context if already subscribed
        if !(context is PaywallContext && EntitlementManager.shared.isSubscriber) || !isTopUp {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Or Subscribe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Spacer()
                }

                // Monthly / Annual toggle (only show if annual product exists)
                if store.chefsTableAnnualProduct != nil {
                    Picker("Billing", selection: $showAnnualBilling) {
                        Text("Monthly").tag(false)
                        Text("Annual").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                // Chef's Table — Monthly or Annual based on toggle
                if showAnnualBilling, let annual = store.chefsTableAnnualProduct {
                    subscriptionCard(
                        product: annual,
                        name: "Chef's Table",
                        credits: "75 credits/month",
                        features: [
                            "All chef personalities",
                            "Recipe reimagination",
                            "Cloud sync",
                            "Clean exports (no watermark)",
                            "Full dashboard & tasting menus"
                        ],
                        isRecommended: true,
                        billingNote: "~$5.83/mo · Save 42%"
                    )
                } else if let chefsTable = store.chefsTableProduct {
                    subscriptionCard(
                        product: chefsTable,
                        name: "Chef's Table",
                        credits: "75 credits/month",
                        features: [
                            "All chef personalities",
                            "Recipe reimagination",
                            "Cloud sync",
                            "Clean exports (no watermark)",
                            "Full dashboard & tasting menus"
                        ],
                        isRecommended: true
                    )
                }

                // Atelier
                if let atelier = store.atelierProduct {
                    subscriptionCard(
                        product: atelier,
                        name: "Atelier",
                        credits: "500 credits/month",
                        features: [
                            "Everything in Chef's Table",
                            "Bulk export",
                            "Creator & B2B features"
                        ],
                        isRecommended: false
                    )
                }

                // Legacy fallback
                if store.chefsTableProduct == nil && store.atelierProduct == nil {
                    if let monthly = store.monthlyProduct {
                        subscriptionCard(
                            product: monthly,
                            name: "Chef's Table",
                            credits: "75 credits/month",
                            features: [
                                "All chef personalities",
                                "Recipe reimagination",
                                "Cloud sync & clean exports"
                            ],
                            isRecommended: true
                        )
                    }
                }

                if store.subscriptionProducts.isEmpty && store.isLoading {
                    loadingPlaceholder
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var isTopUp: Bool {
        if case .topUp = context { return true }
        return false
    }

    private func subscriptionCard(
        product: Product,
        name: String,
        credits: String,
        features: [String],
        isRecommended: Bool,
        billingNote: String? = nil
    ) -> some View {
        let isThisPurchasing = purchasingProductId == product.id

        return Button {
            purchaseProduct(product)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.darkTextPrimary)

                            if isRecommended {
                                Text("Recommended")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.gold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.gold.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(credits)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.visual)
                    }

                    Spacer()

                    if isThisPurchasing {
                        ProgressView().tint(Theme.gold)
                    } else {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(product.displayPrice)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                            if let billingNote {
                                Text(billingNote)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.gold.opacity(0.8))
                            } else {
                                Text("/month")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.darkTextHint)
                            }
                        }
                    }
                }

                // Feature list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.gold)
                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.darkTextSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isRecommended ? Theme.gold.opacity(0.4) : Theme.darkStroke,
                            lineWidth: isRecommended ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
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
                    if store.isPro { dismiss() }
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
        let isCreditPack = StoreManager.creditPackAmounts.keys.contains(product.id)
        Task {
            isPurchasing = true
            purchasingProductId = product.id
            errorMessage = nil
            do {
                let success = try await store.purchase(product)
                if success {
                    HapticManager.medium()
                    // After credit pack purchase, check if we should nudge toward subscription
                    if isCreditPack && UsageTracker.shared.shouldShowSubscriptionNudge {
                        showSubscriptionNudge = true
                    } else {
                        dismiss()
                    }
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

// MARK: - Subscription Upgrade Nudge

private struct SubscriptionNudgeSheet: View {
    let totalSpend: Double
    let onViewSubscription: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 24)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.gold)

                Text("Save with Chef's Table")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text("You've spent \(totalSpend, format: .currency(code: "USD")) on credits. Chef's Table gives you **75 credits/month** plus all chef personalities, reimagination, and clean exports for just $9.99/mo.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button {
                        onViewSubscription()
                    } label: {
                        Text("View Subscription")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.darkBg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("Not now")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextHint)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}
