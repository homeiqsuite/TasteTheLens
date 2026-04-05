import SwiftUI

struct PreferencesView: View {
    @AppStorage("userSkillLevel") private var userSkillLevel = "homeCook"

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Cooking Experience
                cookingExperienceSection

                // Dietary Preferences
                DietaryPreferenceSection(showSaveConfirmation: true)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cooking Experience

    private var cookingExperienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cooking Experience")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                skillLevelCard(
                    id: "beginner",
                    icon: "leaf",
                    title: "Beginner",
                    subtitle: "Simple recipes, basic techniques",
                    color: Theme.visual
                )
                skillLevelCard(
                    id: "homeCook",
                    icon: "frying.pan",
                    title: "Home Cook",
                    subtitle: "Comfortable in the kitchen",
                    color: Theme.gold
                )
                skillLevelCard(
                    id: "adventurous",
                    icon: "flame",
                    title: "Adventurous",
                    subtitle: "Bring on the challenge",
                    color: Theme.culinary
                )
            }
            .padding(.horizontal, 16)

            Text("Recipes are tailored to your experience level")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textQuaternary)
                .padding(.horizontal, 20)
        }
    }

    private func skillLevelCard(id: String, icon: String, title: String, subtitle: String, color: Color) -> some View {
        let isSelected = userSkillLevel == id

        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                userSkillLevel = id
            }
            Task { await SyncManager.shared.syncDietaryPreferences() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? color : Theme.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? color.opacity(0.12) : Theme.buttonBg)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.04) : Theme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color.opacity(0.5) : Theme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
    }
}
