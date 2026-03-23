import SwiftUI

struct OnboardingDietarySection: View {
    @Binding var selected: Set<DietaryPreference>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(DietaryPreference.allCases) { pref in
                dietaryChip(pref)
            }
        }
    }

    private func dietaryChip(_ pref: DietaryPreference) -> some View {
        let isSelected = selected.contains(pref)
        return Button {
            HapticManager.light()
            if isSelected {
                selected.remove(pref)
            } else {
                selected.insert(pref)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: pref.icon)
                    .font(.system(size: 12))
                Text(pref.displayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.gold.opacity(0.15) : Theme.glassCardFill)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Theme.gold : Theme.darkStroke, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextSecondary)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}
