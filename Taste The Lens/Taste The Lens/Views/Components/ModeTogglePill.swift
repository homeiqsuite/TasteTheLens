import SwiftUI

/// Two-segment capsule that switches between Single and Fusion capture modes.
/// A discoverable companion to the long-press-shutter shortcut.
struct ModeTogglePill: View {
    /// Display state — drive from `fusionState.isActive`.
    var isFusion: Bool
    /// Fires only on a genuine mode change, carrying the requested mode.
    var onSelect: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let segmentWidth: CGFloat = 78
    private let segmentHeight: CGFloat = 30

    var body: some View {
        ZStack(alignment: isFusion ? .trailing : .leading) {
            Capsule()
                .fill(.white)
                .frame(width: segmentWidth, height: segmentHeight)

            HStack(spacing: 0) {
                segment(title: "Single", icon: "camera", isSelected: !isFusion) {
                    if isFusion { onSelect(false) }
                }
                segment(title: "Fusion", icon: "sparkles", isSelected: isFusion) {
                    if !isFusion { onSelect(true) }
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(.black.opacity(0.3))
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
        )
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.85),
            value: isFusion
        )
    }

    private func segment(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.darkBg : Theme.darkTextSecondary)
            .frame(width: segmentWidth, height: segmentHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) mode")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isFusion = false
    return ZStack {
        Color.black.ignoresSafeArea()
        ModeTogglePill(isFusion: isFusion) { isFusion = $0 }
    }
}
