import SwiftUI
import UIKit

enum Theme {
    // MARK: - Backgrounds (Light)
    static let background = Color(red: 0.98, green: 0.973, blue: 0.96)       // #FAF8F5
    static let cardSurface = Color.white                                       // #FFFFFF
    static let cardBorder = Color(red: 0.91, green: 0.894, blue: 0.875)       // #E8E4DF
    static let divider = Color(red: 0.929, green: 0.914, blue: 0.894)         // #EDE9E4
    static let buttonBg = Color(red: 0.941, green: 0.925, blue: 0.906)        // #F0ECE7

    // MARK: - Backgrounds (Dark)
    static let darkBg = Color(red: 0.051, green: 0.051, blue: 0.059)          // #0D0D0F
    static let glassCardFill = Color(red: 0.11, green: 0.11, blue: 0.137)     // #1C1C23

    // MARK: - Primary & Accents
    static let primary = Color(red: 0.722, green: 0.584, blue: 0.188)         // #B89530
    static let primaryLight = Color(red: 0.722, green: 0.584, blue: 0.188).opacity(0.08)
    static let gold = Color(red: 0.831, green: 0.643, blue: 0.227)            // #D4A43A
    static let visual = Color(red: 0.227, green: 0.62, blue: 0.561)           // #3A9E8F (teal — photography/visual domain)
    static let culinary = Color(red: 0.784, green: 0.42, blue: 0.314)         // #C86B50 (terracotta — cooking/culinary domain)

    // MARK: - Text (Light theme)
    static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)     // #1A1A1A
    static let textSecondary = Color(red: 0.29, green: 0.29, blue: 0.29)      // #4A4A4A
    static let textTertiary = Color(red: 0.541, green: 0.541, blue: 0.541)    // #8A8A8A
    static let textQuaternary = Color(red: 0.69, green: 0.69, blue: 0.69)     // #B0B0B0

    // MARK: - Text (Dark theme)
    static let darkTextPrimary = Color.white                                    // headings, emphasis
    static let darkTextSecondary = Color.white.opacity(0.7)                     // body text, descriptions
    static let darkTextTertiary = Color.white.opacity(0.5)                      // labels, captions
    static let darkTextHint = Color.white.opacity(0.3)                          // hints, disabled

    // MARK: - Surfaces (Dark theme)
    static let darkStroke = Color.white.opacity(0.1)                            // borders, separators
    static let darkSurface = Color.white.opacity(0.06)                          // subtle fills, overlays

    // MARK: - Interactive
    static let checkOff = Color(red: 0.773, green: 0.753, blue: 0.729)        // #C5C0BA
    static let checkOn = primary

    // MARK: - UIColor equivalents (for PDF rendering, UIKit contexts)
    static let goldUI = UIColor(red: 0.831, green: 0.643, blue: 0.227, alpha: 1)
    static let goldUI30 = UIColor(red: 0.831, green: 0.643, blue: 0.227, alpha: 0.3)
}
