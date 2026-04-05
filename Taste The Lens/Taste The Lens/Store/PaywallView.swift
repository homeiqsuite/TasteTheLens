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
            return UsageTracker.shared.canGenerate ? "Get More Credits" : "Out of Credits"
        case .featureGated:
            return "Unlock Everything"
        case .topUp:
            return "Get More Credits"
        }
    }

    var subtitle: String {
        switch self {
        case .outOfGenerations:
            return "Unlock more generations and keep creating\nwithout limits."
        case .featureGated:
            return "Any credit pack purchase unlocks all premium features"
        case .topUp:
            return "Unlock more generations and keep creating\nwithout limits."
        }
    }

    var icon: String {
        switch self {
        case .outOfGenerations: return "plus.circle.fill"
        case .featureGated: return "lock.open.fill"
        case .topUp: return "plus.circle.fill"
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showAuthGate = false
    @State private var pendingPurchaseAfterAuth = false

    private let store = StoreManager.shared
    private let usage = UsageTracker.shared
    private let authManager = AuthManager.shared

    /// Base price per credit (Taste pack: $1.99 / 10 = $0.199)
    private let basePricePerCredit: Double = 0.199

    init(context: PaywallContext = .outOfGenerations) {
        self.context = context
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    dismissButton
                        .padding(.top, 16)

                    headerSection
                    creditBalanceBadge
                    unlockBanner
                    creditPacksSection
                    trustBadge
                    errorSection

                    Spacer().frame(height: 140)
                }
            }

            stickyCTA
        }
        .onAppear { preselectDefault() }
        .sheet(isPresented: $showAuthGate) {
            AuthPromptSheet(
                icon: "lock.open.fill",
                title: "Account Required",
                subtitle: "Create a free account to protect your purchase. Credits are tied to your account so they're never lost.",
                buttonLabel: "Sign In / Create Account"
            )
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && pendingPurchaseAfterAuth {
                pendingPurchaseAfterAuth = false
                if let product = selectedProduct {
                    purchaseProduct(product)
                }
            }
        }
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .padding(10)
                    .background(Theme.darkSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.darkStroke, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            // Gold circle icon
            ZStack {
                Circle()
                    .stroke(Theme.gold, lineWidth: 2)
                    .frame(width: 56, height: 56)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.bottom, 4)

            Text(context.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)

            Text(context.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
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
                HStack(spacing: 0) {
                    Text("\(totalCredits) ")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.darkTextPrimary)
                    Text("credits remaining")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.darkTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.visual.opacity(0.08))
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
                    .font(.system(size: 13))
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
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Credit Packs

    private var creditPacksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header
            Text("CHOOSE A CREDIT PACK")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.darkTextTertiary)
                .tracking(0.8)

            // Hint
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextHint)
                Text("1 credit = 1 generation")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextHint)
            }
            .padding(.bottom, 8)

            if store.creditProducts.isEmpty && store.isLoading {
                loadingPlaceholder
            }

            // Cards
            VStack(spacing: 12) {
                ForEach(store.creditProducts) { product in
                    creditPackCard(product: product)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func creditPackCard(product: Product) -> some View {
        let credits = StoreManager.creditPackAmounts[product.id] ?? 0
        let isSelected = selectedProduct?.id == product.id
        let isMostPopular = product.id == StoreManager.cookPackId
        let savings = packSavings(for: product.id)
        let priceDouble = NSDecimalNumber(decimal: product.price).doubleValue
        let perCredit = credits > 0 ? priceDouble / Double(credits) : 0

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedProduct = product
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Radio button
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Theme.visual : Theme.darkStroke, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(Theme.visual)
                                .frame(width: 14, height: 14)
                        }
                    }

                    // Credits + pack name
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(credits)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Theme.darkTextPrimary)
                            Text("credits")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.darkTextSecondary)
                        }

                        Text(packSubtitle(for: product.id))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.darkTextHint)
                    }

                    Spacer()

                    // Savings + per-credit pricing + price
                    VStack(alignment: .trailing, spacing: 4) {
                        if let savings {
                            Text(savings)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.2, green: 0.65, blue: 0.3))
                                .clipShape(Capsule())
                        }

                        // Price
                        HStack(spacing: 6) {
                            Text(product.displayPrice)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.darkTextPrimary)

                            if isSelected {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.darkTextHint)
                            }
                        }

                        // Per-credit cost (with strikethrough base if discounted)
                        if savings != nil {
                            HStack(spacing: 4) {
                                Text(String(format: "$%.2f", basePricePerCredit))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.darkTextHint)
                                    .strikethrough(true, color: Theme.darkTextHint)
                                Text(String(format: "$%.2f per credit", perCredit))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.darkTextTertiary)
                            }
                        } else {
                            Text(String(format: "$%.2f per credit", perCredit))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.darkTextHint)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Theme.visual.opacity(0.06) : Theme.darkSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? Theme.visual : Theme.darkStroke,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    if isMostPopular {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                            Text("Most Popular")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Theme.visual)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Theme.darkBg)
                                .overlay(
                                    Capsule()
                                        .fill(Theme.visual.opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Theme.visual.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .offset(x: 14, y: -12)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private func packSubtitle(for productId: String) -> String {
        switch productId {
        case StoreManager.tastePackId: return "Starter pack"
        case StoreManager.cookPackId:  return "Great value"
        case StoreManager.feastPackId: return "Best value"
        default: return ""
        }
    }

    private func packSavings(for productId: String) -> String? {
        switch productId {
        case StoreManager.cookPackId:  return "Save 15%"
        case StoreManager.feastPackId: return "Save 35%"
        default: return nil
        }
    }

    // MARK: - Trust Badge

    private var trustBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.darkTextHint)
            Text("Secure payment via Apple  •  One-time purchase  •  No subscription")
                .font(.system(size: 11))
                .foregroundStyle(Theme.darkTextHint)
        }
        .padding(.horizontal, 20)
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

    // MARK: - Sticky CTA

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Theme.darkBg.opacity(0), Theme.darkBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)

            VStack(spacing: 12) {
                // CTA button — purple gradient
                Button {
                    guard let product = selectedProduct else { return }
                    purchaseProduct(product)
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            let credits = selectedProduct.flatMap { StoreManager.creditPackAmounts[$0.id] } ?? 0
                            let price = selectedProduct?.displayPrice ?? ""

                            Text("Continue with \(credits) Credits")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)

                            Spacer()

                            HStack(spacing: 4) {
                                Text(price)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: selectedProduct != nil
                                ? [
                                    Color(red: 0.35, green: 0.15, blue: 0.65),
                                    Color(red: 0.55, green: 0.20, blue: 0.75),
                                    Color(red: 0.65, green: 0.25, blue: 0.80)
                                  ]
                                : [Theme.visual.opacity(0.3), Theme.visual.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.25, blue: 0.75).opacity(0.6),
                                        Color(red: 0.65, green: 0.30, blue: 0.85).opacity(0.4)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .disabled(selectedProduct == nil || isPurchasing)

                // Footer links
                HStack(spacing: 24) {
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
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.darkTextHint)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .background(Theme.darkBg)
        }
    }

    // MARK: - Helpers

    private var loadingPlaceholder: some View {
        Text("Loading pricing...")
            .font(.system(size: 14))
            .foregroundStyle(Theme.darkTextTertiary)
            .padding(.vertical, 12)
    }

    private func preselectDefault() {
        if let cook = store.creditProducts.first(where: { $0.id == StoreManager.cookPackId }) {
            selectedProduct = cook
        } else {
            selectedProduct = store.creditProducts.first
        }
    }

    private func purchaseProduct(_ product: Product) {
        guard authManager.isAuthenticated else {
            pendingPurchaseAfterAuth = true
            showAuthGate = true
            return
        }

        Task {
            isPurchasing = true
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
        }
    }
}
