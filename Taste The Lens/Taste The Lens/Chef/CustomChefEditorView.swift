import SwiftUI

struct CustomChefEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var currentStep = 0
    @State private var skillLevel: SkillLevel = .homeCook
    @State private var selectedCuisines: Set<CuisineOption> = []
    @State private var personality: PersonalityStyle = .theClassic

    private let totalSteps = 3

    init() {
        // Pre-populate from existing config if editing
        if let config = CustomChefConfig.load() {
            _skillLevel = State(initialValue: config.skillLevel)
            _selectedCuisines = State(initialValue: Set(config.cuisines))
            _personality = State(initialValue: config.personality)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Progress dots
            progressDots
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Step content
            TabView(selection: $currentStep) {
                skillLevelStep.tag(0)
                cuisinesStep.tag(1)
                personalityStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Theme.darkBg)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .frame(width: 32, height: 32)
                    .background(Theme.darkCardSurface)
                    .clipShape(Circle())
            }

            Spacer()

            Text(stepTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)

            Spacer()

            // Invisible balance element
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: "Skill Level"
        case 1: "Cuisines"
        case 2: "Personality"
        default: ""
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step == currentStep ? ChefTheme.custom.accent : Theme.darkCardBorder)
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Skill Level

    private var skillLevelStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("How do you cook?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .padding(.bottom, 4)

                ForEach(SkillLevel.allCases) { level in
                    skillLevelCard(level)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func skillLevelCard(_ level: SkillLevel) -> some View {
        let isSelected = skillLevel == level

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                skillLevel = level
            }
            HapticManager.light()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(ChefTheme.custom.accent.opacity(isSelected ? 0.20 : 0.10))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: level.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(ChefTheme.custom.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : Theme.darkTextPrimary)

                    Text(level.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ChefTheme.custom.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? ChefTheme.custom.accent.opacity(0.08) : Theme.darkCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? ChefTheme.custom.accent.opacity(0.6) : Theme.darkCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Cuisines

    private var cuisinesStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Pick your cuisines")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("\(selectedCuisines.count) selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ChefTheme.custom.accent)
                }
                .padding(.bottom, 4)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ], spacing: 10) {
                    ForEach(CuisineOption.allCases) { cuisine in
                        cuisineChip(cuisine)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func cuisineChip(_ cuisine: CuisineOption) -> some View {
        let isSelected = selectedCuisines.contains(cuisine)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedCuisines.remove(cuisine)
                } else {
                    selectedCuisines.insert(cuisine)
                }
            }
            HapticManager.light()
        } label: {
            VStack(spacing: 6) {
                Text(cuisine.flag)
                    .font(.system(size: 28))

                Text(cuisine.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Theme.darkTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ChefTheme.custom.accent.opacity(0.15) : Theme.darkCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? ChefTheme.custom.accent.opacity(0.6) : Theme.darkCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Personality

    private var personalityStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose a personality")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .padding(.bottom, 4)

                ForEach(PersonalityStyle.allCases) { style in
                    personalityCard(style)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func personalityCard(_ style: PersonalityStyle) -> some View {
        let isSelected = personality == style

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                personality = style
            }
            HapticManager.light()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(ChefTheme.custom.accent.opacity(isSelected ? 0.20 : 0.10))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: style.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(ChefTheme.custom.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(style.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSelected ? Color.white : Theme.darkTextPrimary)

                        Text(style.tagline)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ChefTheme.custom.accent.opacity(0.8))
                    }

                    Text(style.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ChefTheme.custom.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? ChefTheme.custom.accent.opacity(0.08) : Theme.darkCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? ChefTheme.custom.accent.opacity(0.6) : Theme.darkCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.darkCardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.darkCardBorder, lineWidth: 0.5)
                        )
                }
            }

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    saveAndDismiss()
                }
            } label: {
                Text(currentStep < totalSteps - 1 ? "Next" : "Save")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canProceed ? ChefTheme.custom.accent : ChefTheme.custom.accent.opacity(0.3))
                    )
            }
            .disabled(!canProceed)
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: true // Skill level always has a selection
        case 1: !selectedCuisines.isEmpty
        case 2: true // Personality always has a selection
        default: true
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        let config = CustomChefConfig(
            skillLevel: skillLevel,
            cuisines: Array(selectedCuisines),
            personality: personality
        )
        CustomChefConfig.save(config)
        selectedChef = "custom"
        HapticManager.medium()
        dismiss()
    }
}

#Preview {
    CustomChefEditorView()
}
