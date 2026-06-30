import SwiftUI

struct ChefTheme {
    // MARK: - Backgrounds
    let dashboardBg: Color
    let cardBg: Color
    let cardShadow: Color
    let cardBorder: Color

    // MARK: - Accents
    let accent: Color
    let accentDeep: Color
    let accentOrange: Color

    // MARK: - Feature Colors
    let impactColor: Color

    // MARK: - Gradients
    let heroGradient: LinearGradient
    let ctaGradient: LinearGradient
    let impactGradient: LinearGradient

    // MARK: - Text
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textQuaternary: Color

    // MARK: - Hero Card Personality
    let heroIcon: String
    let heroSubtitle: String

    // MARK: - Color Scheme
    let prefersDarkMode: Bool
}

// MARK: - Chef Theme Definitions

extension ChefTheme {
    /// The Chef — warm gold, light theme (current default)
    static let defaultChef = ChefTheme(
        dashboardBg: Color(red: 0.992, green: 0.976, blue: 0.957),       // #FDF9F4
        cardBg: Color(red: 1.0, green: 0.992, blue: 0.976),              // #FFFDF9
        cardShadow: Color(red: 0.910, green: 0.659, blue: 0.196).opacity(0.06),
        cardBorder: Color(red: 0.91, green: 0.894, blue: 0.875),         // #E8E4DF
        accent: Color(red: 0.910, green: 0.659, blue: 0.196),            // #E8A832
        accentDeep: Color(red: 0.820, green: 0.533, blue: 0.114),        // #D1881D
        accentOrange: Color(red: 0.937, green: 0.522, blue: 0.153),      // #EF8527
        impactColor: Color(red: 0.906, green: 0.396, blue: 0.463),       // #E76576
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.953, green: 0.718, blue: 0.263),
                Color(red: 0.937, green: 0.561, blue: 0.196),
                Color(red: 0.898, green: 0.439, blue: 0.165),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.953, green: 0.718, blue: 0.263),
                Color(red: 0.910, green: 0.561, blue: 0.173),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.906, green: 0.396, blue: 0.463),
                Color(red: 0.910, green: 0.659, blue: 0.196),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "camera.fill",
        heroSubtitle: "Turn anything into a recipe in seconds",
        prefersDarkMode: false
    )

    /// Dooby — midnight purple, neon accents, dark theme
    static let dooby = ChefTheme(
        dashboardBg: Color(red: 0.071, green: 0.063, blue: 0.118),       // #12101E
        cardBg: Color(red: 0.110, green: 0.094, blue: 0.188),            // #1C1830
        cardShadow: Color(red: 0.706, green: 0.431, blue: 1.0).opacity(0.08),
        cardBorder: Color.white.opacity(0.08),
        accent: Color(red: 0.706, green: 0.431, blue: 1.0),              // #B46EFF
        accentDeep: Color(red: 0.545, green: 0.310, blue: 0.812),        // #8B4FCF
        accentOrange: Color(red: 1.0, green: 0.420, blue: 0.616),        // #FF6B9D
        impactColor: Color(red: 1.0, green: 0.420, blue: 0.616),         // #FF6B9D
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.706, green: 0.431, blue: 1.0),              // #B46EFF
                Color(red: 0.878, green: 0.380, blue: 0.745),            // #E061BE
                Color(red: 1.0, green: 0.420, blue: 0.616),              // #FF6B9D
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.706, green: 0.431, blue: 1.0),
                Color(red: 1.0, green: 0.420, blue: 0.616),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.420, blue: 0.616),
                Color(red: 0.706, green: 0.431, blue: 1.0),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.941, green: 0.925, blue: 0.961),       // #F0ECF5
        textSecondary: Color(red: 0.784, green: 0.749, blue: 0.839),     // #C8BFD6
        textTertiary: Color(red: 0.608, green: 0.561, blue: 0.710),      // #9B8FB5
        textQuaternary: Color(red: 0.420, green: 0.373, blue: 0.502),    // #6B5F80
        heroIcon: "moon.stars.fill",
        heroSubtitle: "Snap your midnight masterpiece",
        prefersDarkMode: true
    )

    /// The Beginner — soft green, friendly, light theme
    static let beginner = ChefTheme(
        dashboardBg: Color(red: 0.957, green: 0.980, blue: 0.965),       // #F4FAF6
        cardBg: Color(red: 0.980, green: 1.0, blue: 0.976),              // #FAFFF9
        cardShadow: Color(red: 0.298, green: 0.686, blue: 0.471).opacity(0.06),
        cardBorder: Color(red: 0.847, green: 0.906, blue: 0.867),        // #D8E7DD
        accent: Color(red: 0.298, green: 0.686, blue: 0.471),            // #4CAF78
        accentDeep: Color(red: 0.180, green: 0.545, blue: 0.341),        // #2E8B57
        accentOrange: Color(red: 0.482, green: 0.776, blue: 0.494),      // #7BC67E
        impactColor: Color(red: 1.0, green: 0.541, blue: 0.502),         // #FF8A80
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.361, green: 0.788, blue: 0.541),            // #5CC98A
                Color(red: 0.298, green: 0.686, blue: 0.471),            // #4CAF78
                Color(red: 0.227, green: 0.620, blue: 0.561),            // #3A9E8F
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.361, green: 0.788, blue: 0.541),
                Color(red: 0.298, green: 0.686, blue: 0.471),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.541, blue: 0.502),
                Color(red: 0.298, green: 0.686, blue: 0.471),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "leaf.fill",
        heroSubtitle: "Take a photo, get an easy recipe",
        prefersDarkMode: false
    )

    /// Grizzly — earthy dark, amber and forest, dark theme
    static let grizzly = ChefTheme(
        dashboardBg: Color(red: 0.102, green: 0.082, blue: 0.063),       // #1A1510
        cardBg: Color(red: 0.149, green: 0.125, blue: 0.102),            // #26201A
        cardShadow: Color(red: 0.831, green: 0.569, blue: 0.227).opacity(0.08),
        cardBorder: Color.white.opacity(0.08),
        accent: Color(red: 0.831, green: 0.569, blue: 0.227),            // #D4913A
        accentDeep: Color(red: 0.627, green: 0.420, blue: 0.125),        // #A06B20
        accentOrange: Color(red: 0.784, green: 0.420, blue: 0.227),      // #C86B3A
        impactColor: Color(red: 0.420, green: 0.557, blue: 0.314),       // #6B8E50
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.831, green: 0.569, blue: 0.227),            // #D4913A
                Color(red: 0.784, green: 0.420, blue: 0.227),            // #C86B3A
                Color(red: 0.420, green: 0.557, blue: 0.314),            // #6B8E50
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.831, green: 0.569, blue: 0.227),
                Color(red: 0.784, green: 0.420, blue: 0.227),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.420, green: 0.557, blue: 0.314),
                Color(red: 0.831, green: 0.569, blue: 0.227),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.941, green: 0.925, blue: 0.906),       // #F0ECE7
        textSecondary: Color(red: 0.784, green: 0.749, blue: 0.710),     // #C8BFB5
        textTertiary: Color(red: 0.608, green: 0.569, blue: 0.522),      // #9B9185
        textQuaternary: Color(red: 0.420, green: 0.388, blue: 0.349),    // #6B6359
        heroIcon: "flame.fill",
        heroSubtitle: "Capture the wild, cook the feast",
        prefersDarkMode: true
    )

    /// Big & Little Chef — warm coral/amber, playful, light theme
    static let familyChef = ChefTheme(
        dashboardBg: Color(red: 0.996, green: 0.969, blue: 0.949),       // #FEF7F2
        cardBg: Color(red: 1.0, green: 0.984, blue: 0.969),              // #FFFBF7
        cardShadow: Color(red: 0.949, green: 0.502, blue: 0.267).opacity(0.06),
        cardBorder: Color(red: 0.922, green: 0.875, blue: 0.851),        // #EBDFD9
        accent: Color(red: 0.949, green: 0.502, blue: 0.267),            // #F28044
        accentDeep: Color(red: 0.820, green: 0.376, blue: 0.153),        // #D16027
        accentOrange: Color(red: 0.988, green: 0.647, blue: 0.298),      // #FCA54C
        impactColor: Color(red: 0.949, green: 0.502, blue: 0.267),       // #F28044
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.988, green: 0.647, blue: 0.298),            // #FCA54C
                Color(red: 0.949, green: 0.502, blue: 0.267),            // #F28044
                Color(red: 0.878, green: 0.345, blue: 0.298),            // #E0584C
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.988, green: 0.647, blue: 0.298),
                Color(red: 0.949, green: 0.502, blue: 0.267),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.988, green: 0.647, blue: 0.298),
                Color(red: 0.878, green: 0.345, blue: 0.298),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "figure.2.and.child.holdinghands",
        heroSubtitle: "Cook together, make memories",
        prefersDarkMode: false
    )

    /// Custom Chef — neutral slate/teal, dark theme
    static let custom = ChefTheme(
        dashboardBg: Color(red: 0.071, green: 0.078, blue: 0.098),             // #121419
        cardBg: Color(red: 0.110, green: 0.122, blue: 0.149),                  // #1C1F26
        cardShadow: Color(red: 0.482, green: 0.620, blue: 0.659).opacity(0.08),
        cardBorder: Color.white.opacity(0.08),
        accent: Color(red: 0.482, green: 0.620, blue: 0.659),                  // #7B9EA8
        accentDeep: Color(red: 0.345, green: 0.482, blue: 0.533),              // #587B88
        accentOrange: Color(red: 0.557, green: 0.729, blue: 0.769),            // #8EBAC4
        impactColor: Color(red: 0.482, green: 0.620, blue: 0.659),             // #7B9EA8
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.482, green: 0.620, blue: 0.659),                  // #7B9EA8
                Color(red: 0.345, green: 0.482, blue: 0.533),                  // #587B88
                Color(red: 0.255, green: 0.376, blue: 0.431),                  // #41606E
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.482, green: 0.620, blue: 0.659),
                Color(red: 0.345, green: 0.482, blue: 0.533),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.557, green: 0.729, blue: 0.769),
                Color(red: 0.482, green: 0.620, blue: 0.659),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.922, green: 0.933, blue: 0.949),             // #EBEEF2
        textSecondary: Color(red: 0.729, green: 0.761, blue: 0.800),           // #BAC2CC
        textTertiary: Color(red: 0.533, green: 0.573, blue: 0.627),            // #8892A0
        textQuaternary: Color(red: 0.373, green: 0.408, blue: 0.455),          // #5F6874
        heroIcon: "slider.horizontal.3",
        heroSubtitle: "Your chef, your rules",
        prefersDarkMode: true
    )

    /// The Nutritionist — fresh emerald/teal, wellness, light theme
    static let healthyFoods = ChefTheme(
        dashboardBg: Color(red: 0.957, green: 0.988, blue: 0.973),       // #F4FCF8
        cardBg: Color(red: 0.976, green: 1.0, blue: 0.988),              // #F9FFFC
        cardShadow: Color(red: 0.114, green: 0.690, blue: 0.541).opacity(0.06),
        cardBorder: Color(red: 0.831, green: 0.918, blue: 0.882),        // #D4EAE1
        accent: Color(red: 0.114, green: 0.690, blue: 0.541),            // #1DB08A
        accentDeep: Color(red: 0.0, green: 0.545, blue: 0.420),          // #008B6B
        accentOrange: Color(red: 0.231, green: 0.812, blue: 0.639),      // #3BCFA3
        impactColor: Color(red: 0.961, green: 0.643, blue: 0.235),       // #F5A43C
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.231, green: 0.812, blue: 0.639),            // #3BCFA3
                Color(red: 0.114, green: 0.690, blue: 0.541),            // #1DB08A
                Color(red: 0.0, green: 0.545, blue: 0.420),              // #008B6B
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.231, green: 0.812, blue: 0.639),
                Color(red: 0.114, green: 0.690, blue: 0.541),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.961, green: 0.643, blue: 0.235),
                Color(red: 0.114, green: 0.690, blue: 0.541),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "heart.fill",
        heroSubtitle: "Nutritious, balanced, delicious",
        prefersDarkMode: false
    )

    /// The Healer — soothing blue, calm, light theme
    static let gerdHealing = ChefTheme(
        dashboardBg: Color(red: 0.957, green: 0.976, blue: 0.992),       // #F4F9FE
        cardBg: Color(red: 0.973, green: 0.984, blue: 1.0),              // #F8FBFF
        cardShadow: Color(red: 0.227, green: 0.541, blue: 0.792).opacity(0.06),
        cardBorder: Color(red: 0.835, green: 0.890, blue: 0.957),        // #D5E3F4
        accent: Color(red: 0.227, green: 0.541, blue: 0.792),            // #3A8ACA
        accentDeep: Color(red: 0.149, green: 0.404, blue: 0.659),        // #2667A8
        accentOrange: Color(red: 0.376, green: 0.667, blue: 0.871),      // #60AADE
        impactColor: Color(red: 0.318, green: 0.722, blue: 0.682),       // #51B8AE
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.376, green: 0.667, blue: 0.871),            // #60AADE
                Color(red: 0.227, green: 0.541, blue: 0.792),            // #3A8ACA
                Color(red: 0.149, green: 0.404, blue: 0.659),            // #2667A8
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.376, green: 0.667, blue: 0.871),
                Color(red: 0.227, green: 0.541, blue: 0.792),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.318, green: 0.722, blue: 0.682),
                Color(red: 0.227, green: 0.541, blue: 0.792),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "cross.fill",
        heroSubtitle: "Gentle, soothing, reflux-safe",
        prefersDarkMode: false
    )

    /// The Botanist — vibrant leaf green, vegan, light theme
    static let plantBased = ChefTheme(
        dashboardBg: Color(red: 0.953, green: 0.980, blue: 0.949),       // #F3FAF2
        cardBg: Color(red: 0.973, green: 1.0, blue: 0.969),              // #F8FFF7
        cardShadow: Color(red: 0.298, green: 0.682, blue: 0.275).opacity(0.06),
        cardBorder: Color(red: 0.839, green: 0.910, blue: 0.831),        // #D6E8D4
        accent: Color(red: 0.298, green: 0.682, blue: 0.275),            // #4CAE46
        accentDeep: Color(red: 0.196, green: 0.541, blue: 0.196),        // #328A32
        accentOrange: Color(red: 0.486, green: 0.776, blue: 0.337),      // #7CC656
        impactColor: Color(red: 0.918, green: 0.561, blue: 0.220),       // #EA8F38
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.486, green: 0.776, blue: 0.337),            // #7CC656
                Color(red: 0.298, green: 0.682, blue: 0.275),            // #4CAE46
                Color(red: 0.196, green: 0.541, blue: 0.196),            // #328A32
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.486, green: 0.776, blue: 0.337),
                Color(red: 0.298, green: 0.682, blue: 0.275),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.918, green: 0.561, blue: 0.220),
                Color(red: 0.298, green: 0.682, blue: 0.275),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "leaf.fill",
        heroSubtitle: "100% plants, maximum flavor",
        prefersDarkMode: false
    )

    /// The Gut Guide — calming periwinkle/indigo, light theme
    static let lowFodmap = ChefTheme(
        dashboardBg: Color(red: 0.965, green: 0.965, blue: 0.992),       // #F6F6FD
        cardBg: Color(red: 0.980, green: 0.980, blue: 1.0),             // #FAFAFF
        cardShadow: Color(red: 0.424, green: 0.388, blue: 0.839).opacity(0.06),
        cardBorder: Color(red: 0.871, green: 0.863, blue: 0.949),        // #DEDCF2
        accent: Color(red: 0.424, green: 0.388, blue: 0.839),           // #6C63D6
        accentDeep: Color(red: 0.310, green: 0.275, blue: 0.722),        // #4F46B8
        accentOrange: Color(red: 0.553, green: 0.522, blue: 0.898),      // #8D85E5
        impactColor: Color(red: 0.424, green: 0.388, blue: 0.839),
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.553, green: 0.522, blue: 0.898),           // #8D85E5
                Color(red: 0.424, green: 0.388, blue: 0.839),           // #6C63D6
                Color(red: 0.310, green: 0.275, blue: 0.722),           // #4F46B8
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.553, green: 0.522, blue: 0.898),
                Color(red: 0.424, green: 0.388, blue: 0.839),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.553, green: 0.522, blue: 0.898),
                Color(red: 0.424, green: 0.388, blue: 0.839),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "stethoscope",
        heroSubtitle: "Gut-friendly, low-FODMAP meals",
        prefersDarkMode: false
    )

    /// The Alkalist — fresh cyan/aqua, light theme
    static let alkaline = ChefTheme(
        dashboardBg: Color(red: 0.949, green: 0.988, blue: 0.992),       // #F2FCFD
        cardBg: Color(red: 0.973, green: 0.996, blue: 1.0),             // #F8FEFF
        cardShadow: Color(red: 0.059, green: 0.710, blue: 0.788).opacity(0.06),
        cardBorder: Color(red: 0.812, green: 0.929, blue: 0.945),        // #CFEDF1
        accent: Color(red: 0.059, green: 0.710, blue: 0.788),           // #0FB5C9
        accentDeep: Color(red: 0.039, green: 0.561, blue: 0.627),        // #0A8FA0
        accentOrange: Color(red: 0.231, green: 0.804, blue: 0.808),      // #3BCDCE
        impactColor: Color(red: 0.961, green: 0.643, blue: 0.235),       // #F5A43C
        heroGradient: LinearGradient(
            colors: [
                Color(red: 0.231, green: 0.804, blue: 0.808),           // #3BCDCE
                Color(red: 0.059, green: 0.710, blue: 0.788),           // #0FB5C9
                Color(red: 0.039, green: 0.561, blue: 0.627),           // #0A8FA0
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        ctaGradient: LinearGradient(
            colors: [
                Color(red: 0.231, green: 0.804, blue: 0.808),
                Color(red: 0.059, green: 0.710, blue: 0.788),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        impactGradient: LinearGradient(
            colors: [
                Color(red: 0.961, green: 0.643, blue: 0.235),
                Color(red: 0.059, green: 0.710, blue: 0.788),
            ],
            startPoint: .leading, endPoint: .trailing
        ),
        textPrimary: Color(red: 0.102, green: 0.102, blue: 0.102),       // #1A1A1A
        textSecondary: Color(red: 0.29, green: 0.29, blue: 0.29),        // #4A4A4A
        textTertiary: Color(red: 0.541, green: 0.541, blue: 0.541),      // #8A8A8A
        textQuaternary: Color(red: 0.69, green: 0.69, blue: 0.69),       // #B0B0B0
        heroIcon: "drop.fill",
        heroSubtitle: "Alkaline, fresh & balanced",
        prefersDarkMode: false
    )
}
