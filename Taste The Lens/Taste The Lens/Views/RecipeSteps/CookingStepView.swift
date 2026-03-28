import SwiftUI

struct CookingStepView: View {
    let recipe: Recipe
    let stepIndex: Int
    let cookingStep: CookingStep
    @Binding var checkedIngredients: Set<String>
    @Binding var servingCount: Int

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Step header
                HStack(spacing: 12) {
                    Text("\(stepIndex + 1)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.darkTextPrimary)
                        .frame(width: 36, height: 36)
                        .background(Theme.primary)
                        .clipShape(Circle())

                    Text("Step \(stepIndex + 1)")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Ingredients for this step
                if !cookingStep.ingredientsUsed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "basket")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.primary)
                            Text("Ingredients for this step")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        ForEach(cookingStep.ingredientsUsed, id: \.self) { ingredient in
                            stepIngredientRow(ingredient: ingredient)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Theme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }

                // Instruction text
                Text(cookingStep.instruction)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                Spacer().frame(height: 20)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private func stepIngredientRow(ingredient: String) -> some View {
        let matchingComponent = recipe.components.first { component in
            component.ingredients.contains(where: { ingredientMatches($0, ingredient) })
        }
        let key = "\(matchingComponent?.name ?? ""):\(ingredient)"
        let isChecked = checkedIngredients.contains(key)

        return Button {
            HapticManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                if isChecked {
                    checkedIngredients.remove(key)
                } else {
                    checkedIngredients.insert(key)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isChecked ? Theme.checkOn : Theme.checkOff)

                Text(scaledIngredient(ingredient))
                    .font(.system(size: 15))
                    .foregroundStyle(isChecked ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(isChecked, color: Theme.textQuaternary)

                Spacer()
            }
            .frame(minHeight: 36)
        }
    }

    private func ingredientMatches(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).lowercased() == b.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func scaledIngredient(_ ingredient: String) -> String {
        let parsed = IngredientParser.parse(ingredient)
        return parsed.scaled(from: recipe.baseServings, to: servingCount)
    }
}
