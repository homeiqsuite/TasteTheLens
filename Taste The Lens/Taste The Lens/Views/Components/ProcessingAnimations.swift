import SwiftUI

struct ColorSwatchRow: View {
    let colors: [String]
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, hex in
                HStack(spacing: 8) {
                    Text(hex)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.darkTextSecondary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.darkStroke, lineWidth: 0.5)
                        )
                }
                .offset(x: appeared ? 0 : 100)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.2),
                    value: appeared
                )
            }
        }
        .onAppear { appeared = true }
    }
}

struct StatusText: View {
    let status: String
    @State private var opacity: Double = 0

    var body: some View {
        Text(status)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.darkTextSecondary)
            .opacity(opacity)
            .onChange(of: status) {
                withAnimation(.easeOut(duration: 0.15)) { opacity = 0 }
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
            }
    }
}

struct GeometricOverlay: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let lineCount = 6
            for i in 0..<lineCount {
                let progress = CGFloat(i) / CGFloat(lineCount)
                let offset = (phase + progress).truncatingRemainder(dividingBy: 1.0)

                var path = Path()
                // Diagonal lines that slowly drift
                let startX = size.width * offset
                let startY: CGFloat = 0
                let endX = size.width * (1.0 - offset)
                let endY = size.height

                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))

                context.stroke(
                    path,
                    with: .color(Theme.darkSurface),
                    lineWidth: 0.5
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - Shared Processing Components

struct ProcessingCancelButton: View {
    var onCancel: (() -> Void)?

    var body: some View {
        Button {
            onCancel?()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.darkTextSecondary)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
        }
    }
}

// MARK: - Ken Burns Modifier

struct KenBurnsModifier: ViewModifier {
    @State private var phase = 0

    private let keyframes: [(scale: CGFloat, x: CGFloat, y: CGFloat)] = [
        (1.0, 0, 0),
        (1.12, 20, -15),
        (1.08, -15, 20),
        (1.15, 10, 10),
    ]

    func body(content: Content) -> some View {
        let current = keyframes[phase % keyframes.count]
        content
            .scaleEffect(current.scale)
            .offset(x: current.x, y: current.y)
            .onAppear {
                advancePhase()
            }
    }

    private func advancePhase() {
        withAnimation(.easeInOut(duration: 8)) {
            phase += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            advancePhase()
        }
    }
}

extension View {
    func kenBurns() -> some View {
        modifier(KenBurnsModifier())
    }
}

// MARK: - Helper to convert hex string to Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
