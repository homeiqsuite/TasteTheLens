import SwiftUI

struct StepNavigationBar: View {
    @Binding var currentStep: Int
    let totalSteps: Int

    private var isFirstStep: Bool { currentStep == 0 }
    private var isLastStep: Bool { currentStep == totalSteps - 1 }

    var body: some View {
        HStack(spacing: 12) {
            // Previous button
            Button {
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStep = max(0, currentStep - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isFirstStep ? Theme.textQuaternary : Theme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(Theme.buttonBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isFirstStep)

            // Next button (hidden on completion step)
            if !isLastStep {
                Button {
                    HapticManager.medium()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep = min(totalSteps - 1, currentStep + 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(nextButtonLabel)
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.darkTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Theme.cardSurface
                .overlay(
                    VStack { Theme.divider.frame(height: 1); Spacer() }
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: -2)
        )
    }

    private var nextButtonLabel: String {
        if currentStep == 0 {
            return "Let's Cook"
        } else if currentStep == totalSteps - 2 {
            return "Finish"
        } else {
            return "Next Step"
        }
    }
}
