import SwiftUI

struct SubstitutionSheet: View {
    let ingredient: String
    let substitutes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.culinary)
                Text("Substitutions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(1)
            }

            Text(ingredient)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(substitutes, id: \.self) { sub in
                    HStack(spacing: 10) {
                        Text("or")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.culinary.opacity(0.6))
                            .frame(width: 24)
                        Text(sub)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(Theme.background)
    }
}
