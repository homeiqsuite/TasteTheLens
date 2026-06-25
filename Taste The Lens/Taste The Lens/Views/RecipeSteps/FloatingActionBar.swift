import SwiftUI

/// Floating two-button action bar pinned to the bottom of the Recipe Detail view.
/// Labels adapt to the current step: prep / cooking / completion.
struct FloatingActionBar: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    var onCookingMode: () -> Void
    var onShare: () -> Void
    var onDone: () -> Void

    private var isPrepStep: Bool { currentStep == 0 }
    private var isCompletionStep: Bool { currentStep == totalSteps - 1 }
    private var isLastCookingStep: Bool { currentStep == totalSteps - 2 }

    var body: some View {
        HStack(spacing: 10) {
            secondaryButton
            primaryButton
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Theme.cardSurface)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Theme.cardBorder, lineWidth: 0.5)
                )
        )
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    @ViewBuilder
    private var secondaryButton: some View {
        if isPrepStep {
            ActionBarButton(label: "Cooking Mode", icon: "hand.raised.slash", style: .secondary, iconLeading: true) {
                HapticManager.medium()
                onCookingMode()
            }
        } else if isCompletionStep {
            ActionBarButton(label: "Share", icon: "square.and.arrow.up", style: .secondary, iconLeading: true) {
                HapticManager.light()
                onShare()
            }
        } else {
            ActionBarButton(label: "Previous", icon: "chevron.left", style: .secondary, iconLeading: true) {
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStep = max(0, currentStep - 1)
                }
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if isCompletionStep {
            ActionBarButton(label: "Done", icon: "checkmark", style: .primary) {
                HapticManager.success()
                onDone()
            }
        } else {
            ActionBarButton(label: primaryLabel, icon: "arrow.right", style: .primary) {
                HapticManager.medium()
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentStep = min(totalSteps - 1, currentStep + 1)
                }
            }
        }
    }

    private var primaryLabel: String {
        if isPrepStep { return "Let's Cook" }
        if isLastCookingStep { return "Finish" }
        return "Next Step"
    }
}

private struct ActionBarButton: View {
    enum Style { case primary, secondary }

    let label: String
    let icon: String
    var style: Style
    var iconLeading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if iconLeading {
                    Image(systemName: icon).font(.system(size: 12, weight: .bold))
                    Text(label).font(.system(size: 15, weight: .semibold))
                } else {
                    Text(label).font(.system(size: 15, weight: .semibold))
                    Image(systemName: icon).font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(style == .primary ? Theme.darkTextPrimary : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(style == .primary ? Theme.textPrimary : Theme.buttonBg)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        FloatingActionBar(currentStep: .constant(0), totalSteps: 6, onCookingMode: {}, onShare: {}, onDone: {})
        FloatingActionBar(currentStep: .constant(2), totalSteps: 6, onCookingMode: {}, onShare: {}, onDone: {})
        FloatingActionBar(currentStep: .constant(5), totalSteps: 6, onCookingMode: {}, onShare: {}, onDone: {})
    }
    .padding()
    .background(Theme.background)
}
