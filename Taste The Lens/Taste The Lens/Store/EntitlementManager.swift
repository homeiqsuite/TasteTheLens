import Foundation
import os

private let logger = makeLogger(category: "Entitlement")

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, Comparable {
    case free
    case chefsTable
    case atelier

    /// Numeric priority for comparison (free < chefsTable < atelier)
    private var priority: Int {
        switch self {
        case .free: return 0
        case .chefsTable: return 1
        case .atelier: return 2
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.priority < rhs.priority
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .chefsTable: return "Chef's Table"
        case .atelier: return "Atelier"
        }
    }

    var monthlyCredits: Int {
        switch self {
        case .free: return 0
        case .chefsTable: return 75
        case .atelier: return 500
        }
    }
}

// MARK: - Feature

enum Feature: CaseIterable {
    case generation
    case chefPersonalities
    case reimagination
    case cloudSync
    case cleanExport
    case unlimitedSaves
    case fullDashboard
    case fullTastingMenus
    case fullChallenges
    case bulkExport
}

// MARK: - Entitlement Manager

@Observable
final class EntitlementManager {
    static let shared = EntitlementManager()

    private init() {}

    var tier: SubscriptionTier {
        StoreManager.shared.currentTier
    }

    var isSubscriber: Bool {
        tier == .chefsTable || tier == .atelier
    }

    func hasAccess(to feature: Feature) -> Bool {
        switch feature {
        case .generation:
            // Generation access is handled by UsageTracker (credits/free gens)
            return true
        case .chefPersonalities, .reimagination, .cloudSync,
             .unlimitedSaves, .fullDashboard, .fullTastingMenus, .fullChallenges:
            return isSubscriber
        case .cleanExport:
            return isSubscriber || UsageTracker.shared.hasPurchasedClassicOrHigher
        case .bulkExport:
            return tier == .atelier
        }
    }

    func requiresUpgrade(for feature: Feature) -> Bool {
        !hasAccess(to: feature)
    }

    /// Discount multiplier for credit pack purchases (subscribers get 10% off)
    var creditDiscountMultiplier: Double {
        isSubscriber ? 0.9 : 1.0
    }
}
