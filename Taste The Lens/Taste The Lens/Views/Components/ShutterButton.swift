import SwiftUI

struct ShutterButton: View {
    let action: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)

                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 70, height: 70)

                // Inner circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 58, height: 58)
            }
            .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
