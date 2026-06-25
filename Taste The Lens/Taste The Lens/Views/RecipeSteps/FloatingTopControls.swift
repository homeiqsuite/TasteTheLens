import SwiftUI

/// Floating circular controls that overlay the recipe hero image —
/// back button (leading), share + more (trailing), with a centered title.
struct FloatingTopControls<MoreMenu: View>: View {
    let title: String
    let onBack: () -> Void
    let onShare: () -> Void
    @ViewBuilder var moreMenu: () -> MoreMenu

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                CircleControlButton(icon: "chevron.left") {
                    HapticManager.light()
                    onBack()
                }
                .accessibilityLabel("Close recipe")

                Spacer()

                HStack(spacing: 10) {
                    CircleControlButton(icon: "square.and.arrow.up") {
                        HapticManager.light()
                        onShare()
                    }
                    .accessibilityLabel("Share recipe")

                    Menu {
                        moreMenu()
                    } label: {
                        CircleControlLabel(icon: "ellipsis")
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
    }
}

private struct CircleControlButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleControlLabel(icon: icon)
        }
        .buttonStyle(.plain)
    }
}

private struct CircleControlLabel: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

#Preview {
    ZStack {
        Color.gray
        FloatingTopControls(
            title: "Recipe",
            onBack: {},
            onShare: {}
        ) {
            Button { } label: { Label("View AI Reasoning", systemImage: "sparkles") }
        }
        .padding(.horizontal, 16)
    }
}
