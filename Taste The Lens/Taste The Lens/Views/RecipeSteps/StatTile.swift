import SwiftUI

/// Compact stat tile — small tinted icon, label, and bold value.
/// Used in the Recipe Detail prep overview for prep time, cook time, calories.
struct StatTile: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)

            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    HStack(spacing: 10) {
        StatTile(icon: "hands.sparkles", iconColor: Theme.visual, label: "Prep", value: "20 min")
        StatTile(icon: "flame", iconColor: Theme.onboardingResult, label: "Cook", value: "35 min")
        StatTile(icon: "flame.fill", iconColor: Theme.gold, label: "Calories", value: "620 kcal")
    }
    .padding()
    .background(Theme.cardSurface)
}
