import Foundation

struct ParsedIngredient {
    let quantity: Double?
    let unit: String?
    let name: String
    let originalString: String

    func scaled(from baseServings: Int, to targetServings: Int) -> String {
        guard let quantity, baseServings > 0 else { return originalString }
        if baseServings == targetServings { return originalString }

        let scaledQty = quantity * Double(targetServings) / Double(baseServings)
        let formatted = formatQuantity(scaledQty)

        if let unit {
            return "\(formatted) \(unit) \(name)"
        } else {
            return "\(formatted) \(name)"
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        // Common fractions for cooking
        let fractions: [(Double, String)] = [
            (0.125, "1/8"), (0.25, "1/4"), (0.333, "1/3"),
            (0.375, "3/8"), (0.5, "1/2"), (0.667, "2/3"),
            (0.75, "3/4"), (0.875, "7/8"),
        ]

        let whole = Int(value)
        let fractional = value - Double(whole)

        // If close to a whole number
        if fractional < 0.06 {
            return whole == 0 ? "1" : "\(whole)"
        }

        // Check if close to a common fraction
        for (frac, str) in fractions {
            if abs(fractional - frac) < 0.06 {
                if whole > 0 {
                    return "\(whole) \(str)"
                }
                return str
            }
        }

        // Fall back to one decimal place
        if whole > 0 && fractional > 0.06 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.1f", value)
    }
}

enum IngredientParser {
    // Matches patterns like: "2 tbsp butter", "1/2 cup flour", "1 1/2 cups sugar", "3 chicken breasts"
    private static let pattern = #"^(\d+\s+\d+/\d+|\d+/\d+|\d+\.?\d*)\s*(tbsp|tsp|cup|cups|oz|lb|lbs|g|kg|ml|L|cloves?|slices?|pieces?|pinch(?:es)?|bunch(?:es)?|sprigs?|stalks?|cans?|heads?|large|medium|small)?\s*(.+)$"#

    static func parse(_ ingredient: String) -> ParsedIngredient {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: ingredient, range: NSRange(ingredient.startIndex..., in: ingredient)) else {
            return ParsedIngredient(quantity: nil, unit: nil, name: ingredient, originalString: ingredient)
        }

        let qtyRange = Range(match.range(at: 1), in: ingredient)!
        let qtyString = String(ingredient[qtyRange])
        let quantity = parseQuantity(qtyString)

        var unit: String?
        if let unitRange = Range(match.range(at: 2), in: ingredient) {
            unit = String(ingredient[unitRange])
        }

        let nameRange = Range(match.range(at: 3), in: ingredient)!
        let name = String(ingredient[nameRange]).trimmingCharacters(in: .whitespaces)

        return ParsedIngredient(quantity: quantity, unit: unit, name: name, originalString: ingredient)
    }

    private static func parseQuantity(_ string: String) -> Double {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Mixed number: "1 1/2"
        if trimmed.contains(" ") && trimmed.contains("/") {
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            if parts.count == 2, let whole = Double(parts[0]) {
                return whole + parseFraction(String(parts[1]))
            }
        }

        // Pure fraction: "1/2"
        if trimmed.contains("/") {
            return parseFraction(trimmed)
        }

        // Decimal or integer
        return Double(trimmed) ?? 0
    }

    private static func parseFraction(_ string: String) -> Double {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0 else { return 0 }
        return numerator / denominator
    }
}
