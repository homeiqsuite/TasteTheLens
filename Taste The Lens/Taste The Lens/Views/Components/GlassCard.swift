import SwiftUI

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, opacity: Double = 0.08) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, opacity: opacity))
    }
}
