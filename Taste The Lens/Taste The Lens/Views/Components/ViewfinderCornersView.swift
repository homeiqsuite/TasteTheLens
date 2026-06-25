import SwiftUI

/// Four L-shaped corner brackets that frame the camera subject — a lightweight
/// "frame your shot" affordance shown over the live preview.
struct ViewfinderCornersView: View {
    var armLength: CGFloat = 28
    var strokeWidth: CGFloat = 2
    var color: Color = .white.opacity(0.9)

    var body: some View {
        ViewfinderCorners(armLength: armLength)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )
            // Keeps the white strokes legible against bright scenes.
            .shadow(color: .black.opacity(0.3), radius: 1)
    }
}

// MARK: - Corner Shape

private struct ViewfinderCorners: Shape {
    var armLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let a = armLength

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + a))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + a, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - a, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + a))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - a))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - a, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + a, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - a))

        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ViewfinderCornersView()
            .frame(width: 280, height: 280)
    }
}
