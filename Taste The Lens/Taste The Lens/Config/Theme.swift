import SwiftUI

enum Theme {
    // MARK: - Backgrounds
    static let background = Color(red: 0.98, green: 0.973, blue: 0.96)       // #FAF8F5
    static let cardSurface = Color.white                                       // #FFFFFF
    static let cardBorder = Color(red: 0.91, green: 0.894, blue: 0.875)       // #E8E4DF
    static let divider = Color(red: 0.929, green: 0.914, blue: 0.894)         // #EDE9E4
    static let buttonBg = Color(red: 0.941, green: 0.925, blue: 0.906)        // #F0ECE7

    // MARK: - Primary & Accents
    static let primary = Color(red: 0.722, green: 0.58, blue: 0.18)           // #B8942E
    static let primaryLight = Color(red: 0.722, green: 0.58, blue: 0.18).opacity(0.08)
    static let accent1 = Color(red: 0.165, green: 0.616, blue: 0.561)         // #2A9D8F (teal)
    static let accent2 = Color(red: 0.831, green: 0.388, blue: 0.294)         // #D4634B (terracotta)

    // MARK: - Text
    static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)     // #1A1A1A
    static let textSecondary = Color(red: 0.29, green: 0.29, blue: 0.29)      // #4A4A4A
    static let textTertiary = Color(red: 0.541, green: 0.541, blue: 0.541)    // #8A8A8A
    static let textQuaternary = Color(red: 0.69, green: 0.69, blue: 0.69)     // #B0B0B0

    // MARK: - Interactive
    static let checkOff = Color(red: 0.773, green: 0.753, blue: 0.729)        // #C5C0BA
    static let checkOn = primary

    // MARK: - Legacy (for dark-themed views: CookingMode, Processing)
    static let darkBg = Color(red: 0.051, green: 0.051, blue: 0.059)          // #0D0D0F
    static let gold = Color(red: 0.788, green: 0.659, blue: 0.298)            // #C9A84C
    static let cyan = Color(red: 0.392, green: 0.824, blue: 1.0)              // #64D2FF
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)               // #FF6B6B
}
