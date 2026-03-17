import SwiftUI
import StoreKit
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Paywall")

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private let storeManager = StoreManager.shared
    private let usageTracker = UsageTracker.shared

    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Usage message
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(gold)

                        Text("You've used all your free tastings")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("\(usageTracker.usageCount) of \(usageTracker.usageLimit) free tastings used this month")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer().frame(height: 8)

                    // Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        featureRow(icon: "infinity", text: "Unlimited recipe generations")
                        featureRow(icon: "icloud", text: "Cloud sync across devices")
                        featureRow(icon: "person.2", text: "All chef personalities")
                        featureRow(icon: "arrow.trianglehead.2.clockwise", text: "Recipe reimagination")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)

                    // Pricing buttons
                    VStack(spacing: 12) {
                        if let annual = storeManager.annualProduct {
                            productButton(product: annual, label: "Annual", badge: "Best Value")
                        }

                        if let monthly = storeManager.monthlyProduct {
                            productButton(product: monthly, label: "Monthly", badge: nil)
                        }

                        if storeManager.products.isEmpty {
                            Text("Loading pricing...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Restore
                    Button {
                        Task {
                            await storeManager.restorePurchases()
                            if storeManager.isPro {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    // Dismiss
                    Button {
                        dismiss()
                    } label: {
                        Text("Not now")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(gold)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func productButton(product: Product, label: String, badge: String?) -> some View {
        Button {
            Task {
                isPurchasing = true
                errorMessage = nil
                do {
                    let success = try await storeManager.purchase(product)
                    if success { dismiss() }
                } catch {
                    errorMessage = error.localizedDescription
                    logger.error("Purchase failed: \(error)")
                }
                isPurchasing = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(gold.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.displayPrice)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if isPurchasing {
                    ProgressView()
                        .tint(gold)
                } else {
                    Text("Subscribe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(gold)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(badge != nil ? gold.opacity(0.4) : Color.white.opacity(0.1), lineWidth: badge != nil ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}
