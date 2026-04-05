import SwiftUI

enum TooltipPointer {
    case up
    case down
}

struct CoachTooltip: View {
    let text: String
    var icon: String = "sparkles"
    var pointer: TooltipPointer = .down
    var autoDismissSeconds: Double = 4
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if pointer == .up {
                triangle
                    .rotationEffect(.degrees(180))
            }

            // Bubble
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text(text)
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

            if pointer == .down {
                triangle
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : (pointer == .down ? 8 : -8))
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.4)) {
                isVisible = true
            }
            Task {
                try? await Task.sleep(for: .seconds(autoDismissSeconds))
                dismiss()
            }
        }
        .onTapGesture {
            dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isStaticText)
    }

    private var triangle: some View {
        CoachTriangle()
            .fill(.ultraThinMaterial)
            .frame(width: 14, height: 8)
            .overlay(
                CoachTriangle()
                    .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
            )
    }

    private func dismiss() {
        withAnimation(reduceMotion ? .easeIn(duration: 0.15) : .easeIn(duration: 0.25)) {
            isVisible = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            onDismiss()
        }
    }
}

// MARK: - Triangle Shape

private struct CoachTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
