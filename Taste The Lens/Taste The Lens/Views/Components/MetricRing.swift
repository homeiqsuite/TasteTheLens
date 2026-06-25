import SwiftUI

/// Circular progress ring for a single metric (e.g. "recipes this week").
///
/// Faint tinted track + a rounded-cap progress arc, with the current value
/// rendered in the center. Animates on appear and on value change, and
/// collapses to an instant set when Reduce Motion is on.
struct MetricRing: View {
    enum RingSize {
        case small, large
    }

    let value: Int
    let goal: Int
    /// Small text shown under the value inside the ring (e.g. "of 5").
    var centerSubtitle: String? = nil
    /// Progress arc color.
    let accent: Color
    /// Color of the centered value text.
    let valueColor: Color
    /// Color of the center subtitle text.
    let subtitleColor: Color
    var size: RingSize = .large

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedTrim: CGFloat = 0

    private var dimension: CGFloat { size == .large ? 128 : 78 }
    private var lineWidth: CGFloat { size == .large ? 12 : 8 }

    private var valueFont: Font {
        size == .large
            ? .system(size: 40, weight: .bold, design: .rounded)
            : .system(size: 22, weight: .bold, design: .rounded)
    }

    private var targetProgress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(max(CGFloat(value) / CGFloat(goal), 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedTrim)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: size == .large ? 0 : -1) {
                Text("\(value)")
                    .font(valueFont)
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText())

                if let centerSubtitle {
                    Text(centerSubtitle)
                        .font(size == .large ? .dsCaption : .dsMicro)
                        .foregroundStyle(subtitleColor)
                }
            }
        }
        .frame(width: dimension, height: dimension)
        .onAppear { applyProgress() }
        .onChange(of: targetProgress) { _, _ in applyProgress() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) of \(goal)")
    }

    private func applyProgress() {
        if reduceMotion {
            animatedTrim = targetProgress
        } else {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                animatedTrim = targetProgress
            }
        }
    }
}

#Preview("Metric Ring") {
    ScrollView {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                MetricRing(value: 0, goal: 5, centerSubtitle: "of 5",
                           accent: ChefTheme.defaultChef.accent,
                           valueColor: ChefTheme.defaultChef.textPrimary,
                           subtitleColor: ChefTheme.defaultChef.textTertiary)
                MetricRing(value: 3, goal: 5, centerSubtitle: "of 5",
                           accent: ChefTheme.defaultChef.accent,
                           valueColor: ChefTheme.defaultChef.textPrimary,
                           subtitleColor: ChefTheme.defaultChef.textTertiary)
                MetricRing(value: 5, goal: 5, centerSubtitle: "of 5",
                           accent: ChefTheme.defaultChef.accent,
                           valueColor: ChefTheme.defaultChef.textPrimary,
                           subtitleColor: ChefTheme.defaultChef.textTertiary)
            }
            .padding(24)
            .background(ChefTheme.defaultChef.dashboardBg)

            HStack(spacing: 20) {
                MetricRing(value: 2, goal: 5, centerSubtitle: "of 5",
                           accent: ChefTheme.dooby.accent,
                           valueColor: ChefTheme.dooby.textPrimary,
                           subtitleColor: ChefTheme.dooby.textTertiary, size: .small)
                MetricRing(value: 7, goal: 5, centerSubtitle: "of 5",
                           accent: ChefTheme.dooby.accent,
                           valueColor: ChefTheme.dooby.textPrimary,
                           subtitleColor: ChefTheme.dooby.textTertiary)
            }
            .padding(24)
            .background(ChefTheme.dooby.dashboardBg)
        }
    }
}
