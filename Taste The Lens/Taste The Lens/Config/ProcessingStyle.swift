import Foundation

enum ProcessingStyle: String, CaseIterable, Identifiable {
    case classic
    case miseEnPlace
    case colorToIngredient
    case kitchenPass
    case splitScreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .miseEnPlace: "Mise en Place"
        case .colorToIngredient: "Color to Ingredient"
        case .kitchenPass: "Kitchen Pass"
        case .splitScreen: "Split Screen"
        }
    }

    var description: String {
        switch self {
        case .classic: "Progress steps with color swatches"
        case .miseEnPlace: "Progressive recipe reveal with pan & zoom"
        case .colorToIngredient: "Colors extracted and morphed into ingredients"
        case .kitchenPass: "Restaurant ticket with typewriter effect"
        case .splitScreen: "Side-by-side before and after transformation"
        }
    }

    var iconName: String {
        switch self {
        case .classic: "circle.grid.3x3"
        case .miseEnPlace: "theatermasks"
        case .colorToIngredient: "paintpalette"
        case .kitchenPass: "doc.text"
        case .splitScreen: "rectangle.split.2x1"
        }
    }
}
