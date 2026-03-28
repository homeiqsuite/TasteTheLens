import SwiftUI

struct ShutterButton: View {
    let action: () -> Void
    var onLongPress: (() -> Void)?
    var isFusionMode: Bool = false
    var shotLabel: String?

    @State private var isPulsing = false

    private var accentColor: Color { isFusionMode ? Theme.gold : .white }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)

                // Outer ring
                Circle()
                    .stroke(accentColor, lineWidth: 3)
                    .frame(width: 70, height: 70)

                // Inner circle
                Circle()
                    .fill(accentColor)
                    .frame(width: 58, height: 58)
            }
            .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 0)
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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
