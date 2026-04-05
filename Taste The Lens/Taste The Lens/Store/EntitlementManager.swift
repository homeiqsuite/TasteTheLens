import Foundation
import os

private let logger = makeLogger(category: "Entitlement")

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
}

// MARK: - Entitlement Manager

/// Pure credits entitlement model: any credit purchase unlocks all premium features.
/// Free users (who have never purchased) get watermarked exports only.
@Observable
final class EntitlementManager {
    static let shared = EntitlementManager()

    private init() {}

    /// Whether the user has ever purchased credits (synced from server via `has_ever_purchased`
    /// column, also set locally on credit pack purchase for immediate UI feedback).
    var hasEverPurchased: Bool {
        get { UserDefaults.standard.bool(forKey: "hasEverPurchased") }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasEverPurchased")
            logger.info("hasEverPurchased set to \(newValue)")
        }
    }

    func hasAccess(to feature: Feature) -> Bool {
        switch feature {
        case .generation:
            // Generation access is handled by UsageTracker (credits available)
            return true
        default:
            // All premium features unlock with any purchase
            return hasEverPurchased
        }
    }

    func requiresUpgrade(for feature: Feature) -> Bool {
        !hasAccess(to: feature)
    }
}
