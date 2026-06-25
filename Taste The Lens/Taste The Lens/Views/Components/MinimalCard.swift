import SwiftUI

/// Clean, theme-aware card surface — the minimalist replacement for the heavy
/// `.glassCard()` / `.themedCard()` styles on the dashboard and saved screens.
///
/// Solid `cardBg` fill, hairline border, and a single soft shadow. All colors
/// come from `ChefTheme`, so it adapts to every chef personality.
struct MinimalCard: ViewModifier {
    let theme: ChefTheme
    var radius: CGFloat = DS.Radius.card
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.cardBorder.opacity(0.6), lineWidth: DS.Stroke.hairline)
            )
            .shadow(color: theme.cardShadow, radius: 10, x: 0, y: 3)
    }
}

extension View {
    func minimalCard(
        _ theme: ChefTheme,
        radius: CGFloat = DS.Radius.card,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    ) -> some View {
        modifier(MinimalCard(theme: theme, radius: radius, padding: padding))
    }
}
