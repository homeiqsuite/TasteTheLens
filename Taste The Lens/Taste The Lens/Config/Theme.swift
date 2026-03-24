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
    static let darkBg = Color(red: 0.039, green: 0.039, blue: 0.071)          // #0A0A12
    static let glassCardFill = Color(red: 0.137, green: 0.110, blue: 0.227).opacity(0.95) // rgba(35,28,58,0.95)

    // MARK: - Primary & Accents
    static let primary = Color(red: 0.627, green: 0.459, blue: 0.125)         // #A07520
    static let primaryLight = Color(red: 0.627, green: 0.459, blue: 0.125).opacity(0.08)
    static let gold = Color(red: 0.910, green: 0.659, blue: 0.196)            // #E8A832
    static let visual = Color(red: 0.482, green: 0.247, blue: 0.627)          // #7B3FA0 (purple — photography/visual domain)
    static let culinary = Color(red: 0.780, green: 0.231, blue: 0.557)        // #C73B8E (magenta — cooking/culinary domain)

    // MARK: - Text (Light theme)
    static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)     // #1A1A1A
    static let textSecondary = Color(red: 0.29, green: 0.29, blue: 0.29)      // #4A4A4A
    static let textTertiary = Color(red: 0.541, green: 0.541, blue: 0.541)    // #8A8A8A
    static let textQuaternary = Color(red: 0.69, green: 0.69, blue: 0.69)     // #B0B0B0

    // MARK: - Text (Dark theme)
    static let darkTextPrimary = Color(red: 0.941, green: 0.925, blue: 0.961)  // #F0ECF5
    static let darkTextSecondary = Color(red: 0.784, green: 0.749, blue: 0.839) // #C8BFD6
    static let darkTextTertiary = Color(red: 0.608, green: 0.561, blue: 0.710) // #9B8FB5
    static let darkTextHint = Color(red: 0.420, green: 0.373, blue: 0.502)     // #6B5F80

    // MARK: - Surfaces (Dark theme)
    static let darkCardSurface = Color(red: 0.110, green: 0.110, blue: 0.137)           // #1C1C23 (solid dark card)
    static let darkCardBorder = Color.white.opacity(0.10)                                 // white @10%
    static let darkButtonBg = Color.white.opacity(0.08)                                   // subtle button bg
    static let darkStroke = Color(red: 0.482, green: 0.247, blue: 0.627).opacity(0.35)   // rgba(123,63,160,0.35)
    static let darkSurface = Color(red: 0.482, green: 0.247, blue: 0.627).opacity(0.06)  // purple-tinted fills

    // MARK: - Onboarding Flow Colors
    static let onboardingCapture = Color(red: 0.227, green: 0.620, blue: 0.561)  // #3A9E8F (teal — capture/input)
    static let onboardingResult = Color(red: 0.784, green: 0.420, blue: 0.314)   // #C86B50 (terracotta — recipe/output)
    static let cardElevated = Color(red: 0.082, green: 0.082, blue: 0.102)       // #15151A (elevated card bg)

    // MARK: - Warm Gradients (Dashboard)
    static let goldOrange = Color(red: 0.937, green: 0.522, blue: 0.153)       // #EF8527 (warm orange)
    static let goldDeep = Color(red: 0.820, green: 0.533, blue: 0.114)         // #D1881D (deep gold)
    static let warmPink = Color(red: 0.906, green: 0.396, blue: 0.463)        // #E76576 (warm pink)
    static let warmBg = Color(red: 0.992, green: 0.976, blue: 0.957)          // #FDF9F4 (warm cream bg)
    static let warmCardBg = Color(red: 1.0, green: 0.992, blue: 0.976)        // #FFFDF9 (warm white card)

    // MARK: - Gradient Helpers
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.953, green: 0.718, blue: 0.263),  // bright gold
            Color(red: 0.937, green: 0.561, blue: 0.196),  // gold-orange
            Color(red: 0.898, green: 0.439, blue: 0.165),  // warm orange
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ctaGradient = LinearGradient(
        colors: [
            Color(red: 0.953, green: 0.718, blue: 0.263),  // bright gold
            Color(red: 0.910, green: 0.561, blue: 0.173),  // gold-orange
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let impactGradient = LinearGradient(
        colors: [
            warmPink,
            gold,
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Interactive
    static let checkOff = Color(red: 0.773, green: 0.753, blue: 0.729)        // #C5C0BA
    static let checkOn = primary

    // MARK: - UIColor equivalents (for PDF rendering, UIKit contexts)
    static let goldUI = UIColor(red: 0.910, green: 0.659, blue: 0.196, alpha: 1)
    static let goldUI30 = UIColor(red: 0.910, green: 0.659, blue: 0.196, alpha: 0.3)
}
