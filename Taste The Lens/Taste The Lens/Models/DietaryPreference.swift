import Foundation

enum DietaryPreference: String, CaseIterable, Identifiable, Codable {
    case vegetarian
    case vegan
    case pescatarian
    case glutenFree = "gluten-free"
    case dairyFree = "dairy-free"
    case nutFree = "nut-free"
    case keto
    case lowCarb = "low-carb"
    case halal
    case kosher

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .pescatarian: "Pescatarian"
        case .glutenFree: "Gluten-Free"
        case .dairyFree: "Dairy-Free"
        case .nutFree: "Nut-Free"
        case .keto: "Keto"
        case .lowCarb: "Low-Carb"
        case .halal: "Halal"
        case .kosher: "Kosher"
        }
    }

    var icon: String {
        switch self {
        case .vegetarian: "leaf"
        case .vegan: "leaf.fill"
        case .pescatarian: "fish"
        case .glutenFree: "xmark.circle"
        case .dairyFree: "drop.triangle"
        case .nutFree: "allergens"
        case .keto: "bolt"
        case .lowCarb: "chart.bar"
        case .halal: "checkmark.seal"
        case .kosher: "star"
        }
    }

    // MARK: - Persistence

    private static let storageKey = "dietaryPreferences"

    static func current() -> [DietaryPreference] {
        guard let raw = UserDefaults.standard.stringArray(forKey: storageKey) else { return [] }
        return raw.compactMap { DietaryPreference(rawValue: $0) }
    }

    static func save(_ prefs: [DietaryPreference]) {
        UserDefaults.standard.set(prefs.map(\.rawValue), forKey: storageKey)
    }

    /// Returns the dietary constraint string for injection into AI prompts, or nil if no preferences set.
    static func promptConstraint() -> String? {
        let prefs = current()
        guard !prefs.isEmpty else { return nil }
        let list = prefs.map(\.displayName).joined(separator: ", ")
        return """
        CRITICAL DIETARY CONSTRAINTS: The recipe MUST comply with ALL of the following dietary restrictions: \(list). \
        Do NOT include any ingredients that violate these restrictions. \
        If an ingredient would normally violate a restriction, substitute it with a compliant alternative. \
        Do NOT mention the restrictions were applied — just naturally use compliant ingredients.
        """
    }
}
