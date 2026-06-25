import SwiftUI

/// Layout design tokens — spacing, radii, strokes.
/// Colors are intentionally NOT defined here; they live on `ChefTheme` so the
/// UI adapts to the selected chef personality.
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let pill: CGFloat = 999
        static let card: CGFloat = 20
        static let tile: CGFloat = 14
        static let chip: CGFloat = 12
    }

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let regular: CGFloat = 1
    }

    /// Vertical space the floating tab bar + FAB occupy at the bottom of the
    /// screen. Scrollable tab content should pad past this so nothing hides
    /// behind the bar.
    static let tabBarClearance: CGFloat = 92
}

// MARK: - Typography Scale

extension Font {
    /// Screen / greeting headline.
    static let dsTitle = Font.system(size: 26, weight: .bold)
    /// Section heading above a group of cards.
    static let dsSection = Font.system(size: 18, weight: .semibold)
    /// Large numeric for compact stat tiles.
    static let dsMetric = Font.system(size: 30, weight: .bold, design: .rounded)
    /// Standard body copy.
    static let dsBody = Font.system(size: 15, weight: .regular)
    /// Emphasized body copy (card titles, list rows).
    static let dsBodyEmph = Font.system(size: 15, weight: .semibold)
    /// Secondary caption / metadata.
    static let dsCaption = Font.system(size: 12, weight: .medium)
    /// Smallest label — pill text, overlines.
    static let dsMicro = Font.system(size: 11, weight: .semibold)
}
