import SwiftUI

struct DietaryPreferenceSection: View {
    @State private var selected: Set<DietaryPreference> = Set(DietaryPreference.current())

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dietary Preferences")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .tracking(1.2)

            FlowLayout(spacing: 8) {
                ForEach(DietaryPreference.allCases) { pref in
                    dietaryChip(pref)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )

            Text("Active restrictions are applied to all generated recipes")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textQuaternary)
                .padding(.leading, 4)
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
            DietaryPreference.save(Array(selected))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: pref.icon)
                    .font(.system(size: 11))
                Text(pref.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.primary.opacity(0.12) : Theme.buttonBg)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Theme.primary : Theme.cardBorder, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Theme.primary : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
