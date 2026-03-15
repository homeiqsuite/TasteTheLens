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
                        .foregroundStyle(.white.opacity(0.8))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
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
            .foregroundStyle(.white.opacity(0.7))
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
                    with: .color(.white.opacity(0.06)),
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

// Helper to convert hex string to Color
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
