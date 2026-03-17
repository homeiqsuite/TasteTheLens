import SwiftUI
import AVFoundation

@Observable
final class SpeechManager {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

struct CookingModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var voiceEnabled = false
    @State private var speechManager = SpeechManager()

    private let gold = Theme.gold
    private let bg = Theme.darkBg

    private var allSteps: [(String, String)] {
        var steps: [(String, String)] = []
        for step in recipe.cookingInstructions {
            steps.append(("Cooking", step))
        }
        for step in recipe.platingSteps {
            steps.append(("Plating", step))
        }
        return steps
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        speechManager.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Voice toggle
                    Button {
                        voiceEnabled.toggle()
                        if !voiceEnabled {
                            speechManager.stop()
                        } else if !allSteps.isEmpty {
                            speechManager.speak(allSteps[currentStep].1)
                        }
                    } label: {
                        Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                            .font(.system(size: 18))
                            .foregroundStyle(voiceEnabled ? gold : Theme.darkTextTertiary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                if allSteps.isEmpty {
                    Text("No steps available")
                        .foregroundStyle(Theme.darkTextTertiary)
                } else {
                    VStack(spacing: 24) {
                        // Phase label
                        Text(allSteps[currentStep].0.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(gold.opacity(0.7))

                        // Step counter
                        Text("Step \(currentStep + 1) of \(allSteps.count)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.darkTextTertiary)

                        // Step text
                        Text(allSteps[currentStep].1)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .id(currentStep) // Force transition on step change
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                        // Progress dots
                        HStack(spacing: 6) {
                            ForEach(0..<allSteps.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentStep ? gold : Theme.darkTextHint)
                                    .frame(width: index == currentStep ? 8 : 6, height: index == currentStep ? 8 : 6)
                            }
                        }
                    }
                }

                Spacer()

                // Navigation buttons
                HStack(spacing: 20) {
                    Button {
                        goToStep(currentStep - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(currentStep > 0 ? Theme.darkTextPrimary : Theme.darkTextHint)
                            .frame(width: 64, height: 64)
                            .background(currentStep > 0 ? Theme.darkStroke : Theme.darkSurface)
                            .clipShape(Circle())
                    }
                    .disabled(currentStep <= 0)

                    Button {
                        goToStep(currentStep + 1)
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentStep < allSteps.count - 1 ? "Next" : "Done")
                                .font(.system(size: 18, weight: .semibold))
                            if currentStep < allSteps.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            speechManager.stop()
        }
    }

    private func goToStep(_ step: Int) {
        guard step >= 0 else { return }

        if step >= allSteps.count {
            speechManager.stop()
            dismiss()
            return
        }

        HapticManager.medium()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }

        if voiceEnabled {
            speechManager.speak(allSteps[step].1)
        }
    }
}
