import SwiftUI

struct ShutterButton: View {
    let action: () -> Void
    var onLongPress: (() -> Void)?
    var isFusionMode: Bool = false
    var shotLabel: String?

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accentColor: Color { isFusionMode ? Theme.gold : .white }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Soft pulsing glow
                Circle()
                    .fill(accentColor.opacity(0.10))
                    .frame(width: 88, height: 88)
                    .scaleEffect(isPulsing ? 1.06 : 1.0)

                // Outer ring
                Circle()
                    .stroke(accentColor.opacity(0.95), lineWidth: 2.5)
                    .frame(width: 76, height: 76)

                // Inner fill
                Circle()
                    .fill(accentColor)
                    .frame(width: 64, height: 64)
            }
            .shadow(color: accentColor.opacity(0.20), radius: 8)
            .onTapGesture {
                action()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                HapticManager.heavy()
                onLongPress?()
            }

            // Shot label (only in fusion mode)
            if let shotLabel {
                Text(shotLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.darkBg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.gold, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isFusionMode)
        .animation(.easeInOut(duration: 0.3), value: shotLabel)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 40) {
            ShutterButton(action: {}, isFusionMode: false)
            ShutterButton(action: {}, isFusionMode: true, shotLabel: "2/3")
        }
    }
}
