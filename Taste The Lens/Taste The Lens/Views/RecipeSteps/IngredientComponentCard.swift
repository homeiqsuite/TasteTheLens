import SwiftUI

struct IngredientComponentCard: View {
    let component: RecipeComponent
    let accentColor: Color
    let baseServings: Int
    @Binding var checkedIngredients: Set<String>
    @Binding var servingCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSubstitution: (String, [String]) -> Void

    private let previewCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Header
            Button {
                HapticManager.light()
                onToggle()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(component.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)

                        if !isExpanded {
                            Text(previewText)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textQuaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Expanded ingredient list
            if isExpanded {
                VStack(spacing: 0) {
                    Theme.divider.frame(height: 1).padding(.horizontal, 16)

                    ForEach(component.ingredients, id: \.self) { ingredient in
                        ingredientRow(ingredient: ingredient)
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .lightCard(padding: false)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    private var previewText: String {
        let preview = component.ingredients.prefix(previewCount)
        let names = preview.map { IngredientParser.parse($0).name }
        let joined = names.joined(separator: ", ")
        if component.ingredients.count > previewCount {
            return joined + " +\(component.ingredients.count - previewCount) more"
        }
        return joined
    }

    private func ingredientRow(ingredient: String) -> some View {
        let key = "\(component.name):\(ingredient)"
        let isChecked = checkedIngredients.contains(key)
        let subs = component.substitutions?.first(where: { $0.original == ingredient })

        return HStack(spacing: 12) {
            Button {
                HapticManager.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isChecked {
                        checkedIngredients.remove(key)
                    } else {
                        checkedIngredients.insert(key)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isChecked ? Theme.checkOn : Theme.checkOff)

                    Text(scaledIngredient(ingredient))
                        .font(.system(size: 15))
                        .foregroundStyle(isChecked ? Theme.textTertiary : Theme.textPrimary)
                        .strikethrough(isChecked, color: Theme.textQuaternary)
                }
            }

            Spacer()

            if let subs, !subs.substitutes.isEmpty {
                Button {
                    HapticManager.light()
                    onSubstitution(ingredient, subs.substitutes)
                } label: {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.culinary.opacity(0.6))
                }
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
    }

    private func scaledIngredient(_ ingredient: String) -> String {
        let parsed = IngredientParser.parse(ingredient)
        return parsed.scaled(from: baseServings, to: servingCount)
    }
}
