import SwiftUI

struct LightCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: Bool = true

    func body(content: Content) -> some View {
        content
            .if(padding) { view in
                view
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct DarkCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: Bool = true

    func body(content: Content) -> some View {
        content
            .if(padding) { view in
                view
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.darkCardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Theme.darkCardBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func lightCard(cornerRadius: CGFloat = 16, padding: Bool = true) -> some View {
        modifier(LightCard(cornerRadius: cornerRadius, padding: padding))
    }

    func darkCard(cornerRadius: CGFloat = 16, padding: Bool = true) -> some View {
        modifier(DarkCard(cornerRadius: cornerRadius, padding: padding))
    }
}
