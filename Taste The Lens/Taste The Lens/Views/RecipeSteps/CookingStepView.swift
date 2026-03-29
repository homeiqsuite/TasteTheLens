import SwiftUI

struct CookingStepView: View {
    let recipe: Recipe
    let stepIndex: Int
    let cookingStep: CookingStep
    @Binding var checkedIngredients: Set<String>
    @Binding var servingCount: Int

    /// Resolved ingredients for this step — uses explicit `ingredientsUsed` if available,
    /// otherwise scans the instruction text against all component ingredients.
    private var resolvedIngredients: [(ingredient: String, component: RecipeComponent)] {
        if !cookingStep.ingredientsUsed.isEmpty {
            // AI provided explicit per-step ingredients
            return cookingStep.ingredientsUsed.compactMap { used in
                for component in recipe.components {
                    if component.ingredients.contains(where: { ingredientMatches($0, used) }) {
                        return (used, component)
                    }
                }
                return (used, recipe.components.first ?? RecipeComponent(name: "", ingredients: [], method: ""))
            }
        }

        // Fallback: scan instruction text for mentions of component ingredients
        let instructionLower = cookingStep.instruction.lowercased()
        var matched: [(String, RecipeComponent)] = []
        for component in recipe.components {
            for ingredient in component.ingredients {
                let parsed = IngredientParser.parse(ingredient)
                let name = parsed.name.lowercased()
                if !name.isEmpty && instructionLower.contains(name) {
                    matched.append((ingredient, component))
                }
            }
        }
        return matched
    }

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
                if !resolvedIngredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "basket")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.primary)
                            Text("Ingredients for this step")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        ForEach(Array(resolvedIngredients.enumerated()), id: \.offset) { _, item in
                            stepIngredientRow(ingredient: item.ingredient, component: item.component)
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

                // Cooking tip
                if let tip = cookingStep.tip, !tip.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tip")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.gold)
                            Text(tip)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.gold.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.gold.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 20)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private func stepIngredientRow(ingredient: String, component: RecipeComponent) -> some View {
        let key = "\(component.name):\(ingredient)"
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
