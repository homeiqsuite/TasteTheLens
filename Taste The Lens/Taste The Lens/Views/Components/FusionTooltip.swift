import SwiftUI

struct FusionTooltip: View {
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Bubble
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text("Long-press for Fusion Mode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.darkTextPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                    )
            )

            // Downward triangle
            Triangle()
                .fill(.ultraThinMaterial)
                .frame(width: 14, height: 8)
                .overlay(
                    Triangle()
                        .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                )
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = true
            }
            // Auto-dismiss after 4 seconds
            Task {
                try? await Task.sleep(for: .seconds(4))
                dismiss()
            }
        }
        .onTapGesture {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            onDismiss()
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
