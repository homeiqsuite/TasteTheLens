import SwiftUI

/// Minimal step progress indicator — a single thin capsule bar that fills
/// proportionally with the current step. Replaces the circle-and-connector bar.
struct StepProgressTrack: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        GeometryReader { geo in
            let progress = totalSteps > 0
                ? CGFloat(currentStep + 1) / CGFloat(totalSteps)
                : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.divider)
                Capsule()
                    .fill(Theme.primary)
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}

#Preview {
    VStack(spacing: 24) {
        StepProgressTrack(totalSteps: 6, currentStep: 0)
        StepProgressTrack(totalSteps: 6, currentStep: 2)
        StepProgressTrack(totalSteps: 6, currentStep: 5)
    }
    .padding()
    .background(Theme.cardSurface)
}
