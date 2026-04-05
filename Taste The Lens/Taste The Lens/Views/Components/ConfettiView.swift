import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    @State private var glowOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particleCount = 30

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if reduceMotion {
                    // Reduced motion: brief gold glow pulse
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.gold.opacity(glowOpacity))
                        .ignoresSafeArea()
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.4)) { glowOpacity = 0.15 }
                            withAnimation(.easeOut(duration: 1.2).delay(0.6)) { glowOpacity = 0 }
                        }
                } else {
                    ForEach(particles) { particle in
                        particle.shape
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .rotationEffect(.degrees(isAnimating ? particle.endRotation : 0))
                            .position(
                                x: isAnimating ? particle.endX : particle.startX,
                                y: isAnimating ? particle.endY : particle.startY
                            )
                            .opacity(isAnimating ? 0 : 1)
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                generateParticles(in: proxy.size)
                withAnimation(.easeOut(duration: 2.5)) {
                    isAnimating = true
                }
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            let startX = CGFloat.random(in: 0...size.width)
            let startY: CGFloat = -20
            let endX = startX + CGFloat.random(in: -80...80)
            let endY = size.height + 40
            let size = CGFloat.random(in: 4...10)

            let colors: [Color] = [
                Theme.gold,
                Theme.gold.opacity(0.7),
                Color(red: 0.95, green: 0.78, blue: 0.35),
                Color(red: 0.85, green: 0.60, blue: 0.20),
                Theme.primary,
            ]

            let shapes: [AnyShape] = [
                AnyShape(Circle()),
                AnyShape(RoundedRectangle(cornerRadius: 1)),
                AnyShape(StarShape()),
            ]

            return ConfettiParticle(
                startX: startX,
                startY: startY,
                endX: endX,
                endY: endY,
                size: size,
                color: colors.randomElement()!,
                shape: shapes.randomElement()!,
                endRotation: Double.random(in: 180...720)
            )
        }
    }
}

// MARK: - Particle Model

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let size: CGFloat
    let color: Color
    let shape: AnyShape
    let endRotation: Double
}

// MARK: - Star Shape

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 4

        var path = Path()
        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - (.pi / 2)
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
