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
    let servingCount: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var voiceEnabled = false
    @State private var speechManager = SpeechManager()
    @State private var timerSeconds: Int = 0
    @State private var timerRunning = false
    @State private var timerTotal: Int = 300
    @State private var showTimerPicker = false

    private let gold = Theme.gold
    private let bg = Theme.darkBg

    private var cookingSteps: [CookingStep] {
        recipe.effectiveCookingSteps
    }

    private var allSteps: [(String, String, CookingStep?)] {
        var steps: [(String, String, CookingStep?)] = []
        for step in cookingSteps {
            steps.append(("Cooking", step.instruction, step))
        }
        for step in recipe.platingSteps {
            steps.append(("Plating", step, nil))
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

                    // Timer button
                    Button {
                        if timerRunning {
                            timerRunning = false
                            timerSeconds = 0
                        } else {
                            showTimerPicker = true
                        }
                    } label: {
                        Image(systemName: "timer")
                            .font(.system(size: 18))
                            .foregroundStyle(timerRunning ? gold : Theme.darkTextTertiary)
                            .frame(width: 44, height: 44)
                    }

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

                // Timer display
                if timerRunning {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .foregroundStyle(gold)
                        Text(timerDisplay)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(timerSeconds <= 10 ? Theme.culinary : Theme.darkTextPrimary)
                    }
                    .padding(.vertical, 6)
                }

                if allSteps.isEmpty {
                    Spacer()
                    Text("No steps available")
                        .foregroundStyle(Theme.darkTextTertiary)
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20)

                            // Phase label
                            Text(allSteps[currentStep].0.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(gold.opacity(0.7))

                            // Step counter
                            Text("Step \(currentStep + 1) of \(allSteps.count)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.darkTextTertiary)

                            // Step text — large for hands-free reading
                            Text(allSteps[currentStep].1)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(Theme.darkTextSecondary)
                                .lineSpacing(6)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .id(currentStep)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))

                            // Ingredients for this step
                            if let step = allSteps[currentStep].2, !step.ingredientsUsed.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "basket")
                                            .font(.system(size: 13))
                                            .foregroundStyle(gold)
                                        Text("Ingredients")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.darkTextSecondary)
                                    }
                                    ForEach(step.ingredientsUsed, id: \.self) { ingredient in
                                        let scaled = IngredientParser.parse(ingredient).scaled(from: recipe.baseServings, to: servingCount)
                                        Text("\u{2022} \(scaled)")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Theme.darkTextTertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 32)
                            }

                            // Tip
                            if let step = allSteps[currentStep].2, let tip = step.tip, !tip.isEmpty {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(gold)
                                        .padding(.top, 2)
                                    Text(tip)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.darkTextTertiary)
                                        .lineSpacing(3)
                                }
                                .padding(14)
                                .background(gold.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 24)
                            }

                            // Progress dots
                            HStack(spacing: 6) {
                                ForEach(0..<allSteps.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentStep ? gold : Theme.darkTextHint)
                                        .frame(width: index == currentStep ? 8 : 6, height: index == currentStep ? 8 : 6)
                                }
                            }

                            Spacer().frame(height: 20)
                        }
                    }
                }

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
            timerRunning = false
        }
        .sheet(isPresented: $showTimerPicker) {
            TimerPickerSheet(minutes: timerTotal / 60) { selectedMinutes in
                timerTotal = selectedMinutes * 60
                startTimer()
            }
            .presentationDetents([.height(280)])
        }
    }

    private var timerDisplay: String {
        let m = timerSeconds / 60
        let s = timerSeconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private func startTimer() {
        timerSeconds = timerTotal
        timerRunning = true
        Task {
            while timerSeconds > 0 && timerRunning {
                try? await Task.sleep(for: .seconds(1))
                guard timerRunning else { return }
                timerSeconds -= 1
            }
            if timerRunning && timerSeconds <= 0 {
                HapticManager.success()
                timerRunning = false
            }
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

// MARK: - Timer Picker Sheet

private struct TimerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var minutes: Int

    let onStart: (Int) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Set Timer")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.darkTextPrimary)

            Picker("Minutes", selection: $minutes) {
                ForEach(1...60, id: \.self) { m in
                    Text("\(m) min").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            Button {
                onStart(minutes)
                dismiss()
            } label: {
                Text("Start Timer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 20)
        .background(Theme.darkBg)
    }
}
