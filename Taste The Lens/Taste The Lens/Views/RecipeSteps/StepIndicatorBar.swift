import SwiftUI

struct StepIndicatorBar: View {
    let totalSteps: Int
    @Binding var currentStep: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Button {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep = step
                    }
                } label: {
                    stepCircle(step: step)
                }
                .buttonStyle(.plain)

                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? Theme.primary.opacity(0.4) : Theme.divider)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.cardSurface)
    }

    @ViewBuilder
    private func stepCircle(step: Int) -> some View {
        let isCurrent = step == currentStep
        let isCompleted = step < currentStep

        ZStack {
            if isCompleted {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.darkTextPrimary)
            } else if isCurrent {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 28, height: 28)
                Text(stepLabel(step))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.darkTextPrimary)
            } else {
                Circle()
                    .stroke(Theme.textQuaternary, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Text(stepLabel(step))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func stepLabel(_ step: Int) -> String {
        if step == 0 {
            return "P"
        } else if step == totalSteps - 1 {
            return "✓"
        } else {
            return "\(step)"
        }
    }
}
