import SwiftUI

struct PrepOverviewStep: View {
    let recipe: Recipe
    @Binding var checkedIngredients: Set<String>
    @Binding var expandedSubstitutions: Set<String>
    @Binding var expandedSections: Set<String>
    @Binding var servingCount: Int
    @Binding var showAIReasoning: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                descriptionSection
                dietaryBadges
                quickStatsStrip
                nutritionSection
                ingredientsSection
                moreDetailsSection
                Spacer().frame(height: 20)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        Text(recipe.recipeDescription)
            .font(.system(size: 15))
            .foregroundStyle(Theme.textSecondary)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }


    // MARK: - Dietary Badges

    @ViewBuilder
    private var dietaryBadges: some View {
        let prefs = DietaryPreference.current()
        if !prefs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(prefs) { pref in
                        HStack(spacing: 4) {
                            Image(systemName: pref.icon)
                                .font(.system(size: 10))
                            Text(pref.displayName)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Theme.primary.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Theme.primary.opacity(0.3), lineWidth: 0.5)
                        )
                        .foregroundStyle(Theme.primary)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Quick Stats Strip

    private var quickStatsStrip: some View {
        HStack(spacing: 0) {
            // Servings stepper
            HStack(spacing: 6) {
                Button {
                    if servingCount > 1 {
                        servingCount -= 1
                        HapticManager.selection()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(servingCount > 1 ? Theme.primary : Theme.textQuaternary)
                }
                .disabled(servingCount <= 1)

                VStack(spacing: 1) {
                    Text("\(servingCount)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                    Text("servings")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                .fixedSize()

                Button {
                    if servingCount < 12 {
                        servingCount += 1
                        HapticManager.selection()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(servingCount < 12 ? Theme.primary : Theme.textQuaternary)
                }
                .disabled(servingCount >= 12)
            }
            .fixedSize(horizontal: true, vertical: false)

            // Prep time
            if let prep = recipe.prepTime, !prep.isEmpty {
                dividerLine

                VStack(spacing: 1) {
                    Image(systemName: "hands.sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.visual)
                    Text(prep)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Text("prep")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textQuaternary)
                }
                .frame(maxWidth: .infinity)
            }

            // Cook time
            if let cook = recipe.cookTime, !cook.isEmpty {
                dividerLine

                VStack(spacing: 1) {
                    Image(systemName: "flame")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.culinary)
                    Text(cook)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Text("cook")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textQuaternary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Theme.cardSurface)
        .overlay(
            VStack {
                Theme.divider.frame(height: 1)
                Spacer()
                Theme.divider.frame(height: 1)
            }
        )
        .padding(.top, 8)
    }

    private var dividerLine: some View {
        Theme.divider
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }

    // MARK: - Nutrition

    @ViewBuilder
    private var nutritionSection: some View {
        let nutrition = recipe.nutrition
        let calories = nutrition?.calories ?? recipe.estimatedCalories

        if nutrition != nil || calories != nil {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Nutrition per Serving")

                // Calories prominent display
                if let cals = calories {
                    HStack(spacing: 4) {
                        Text("\(scaledNutrient(cals))")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("kcal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Macro columns
                if let nutrition {
                    HStack(spacing: 0) {
                        macroColumn(value: scaledNutrient(nutrition.protein), label: "Protein", unit: "g", color: Theme.visual)
                        macroColumn(value: scaledNutrient(nutrition.carbs), label: "Carbs", unit: "g", color: Theme.primary)
                        macroColumn(value: scaledNutrient(nutrition.fat), label: "Fat", unit: "g", color: Theme.culinary)
                        macroColumn(value: scaledNutrient(nutrition.fiber), label: "Fiber", unit: "g", color: Theme.gold)
                        macroColumn(value: scaledNutrient(nutrition.sugar), label: "Sugar", unit: "g", color: Theme.textTertiary)
                    }

                    let total = Double(nutrition.protein * 4 + nutrition.carbs * 4 + nutrition.fat * 9)
                    if total > 0 {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                let proteinFrac = Double(nutrition.protein * 4) / total
                                let carbsFrac = Double(nutrition.carbs * 4) / total
                                let fatFrac = Double(nutrition.fat * 9) / total

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Theme.visual)
                                    .frame(width: max(geo.size.width * proteinFrac - 2, 0))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Theme.primary)
                                    .frame(width: max(geo.size.width * carbsFrac - 2, 0))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Theme.culinary)
                                    .frame(width: max(geo.size.width * fatFrac - 2, 0))
                            }
                        }
                        .frame(height: 6)

                        HStack(spacing: 16) {
                            macroLegend(color: Theme.visual, label: "Protein")
                            macroLegend(color: Theme.primary, label: "Carbs")
                            macroLegend(color: Theme.culinary, label: "Fat")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.cardSurface)
            .overlay(
                VStack { Spacer(); Theme.divider.frame(height: 1) }
            )
        }
    }

    private func macroColumn(value: Int, label: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Ingredients")
                Spacer()
                Text("\(checkedIngredients.count)/\(totalIngredientCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            ForEach(Array(recipe.components.enumerated()), id: \.offset) { componentIndex, component in
                if recipe.components.count > 1 {
                    if componentIndex > 0 {
                        Theme.divider.frame(height: 1).padding(.vertical, 4)
                    }
                    Text(component.name.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.primary)
                        .padding(.top, componentIndex > 0 ? 4 : 0)
                }

                ForEach(component.ingredients, id: \.self) { ingredient in
                    ingredientRow(ingredient: ingredient, component: component)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.cardSurface)
        .overlay(
            VStack { Spacer(); Theme.divider.frame(height: 1) }
        )
        .padding(.top, 16)
    }

    private func ingredientRow(ingredient: String, component: RecipeComponent) -> some View {
        let key = "\(component.name):\(ingredient)"
        let isChecked = checkedIngredients.contains(key)
        let isExpanded = expandedSubstitutions.contains(key)
        let subs = component.substitutions?.first(where: { $0.original == ingredient })

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedSubstitutions.remove(key)
                            } else {
                                expandedSubstitutions.insert(key)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.culinary.opacity(0.6))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
            }
            .frame(minHeight: 44)

            if isExpanded, let subs {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(subs.substitutes, id: \.self) { sub in
                        HStack(spacing: 8) {
                            Text("or")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.culinary.opacity(0.5))
                            Text(sub)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .padding(.leading, 34)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - More Details (Deep Dive Panels)

    private var moreDetailsSection: some View {
        VStack(spacing: 0) {
            // Scene Analysis
            if let analysis = recipe.sceneAnalysis, !analysis.detectedItems.isEmpty {
                detailRow(
                    icon: "eye",
                    iconColor: Theme.visual,
                    title: recipe.isFusion ? "How AI read your photos" : "How AI read your photo",
                    sectionKey: "scene"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if recipe.isFusion {
                            let allImages = recipe.allInspirationImages
                            if allImages.count > 1 {
                                HStack(spacing: -8) {
                                    ForEach(Array(allImages.enumerated()), id: \.offset) { index, img in
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 32, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Theme.gold, lineWidth: 1)
                                            )
                                            .zIndex(Double(allImages.count - index))
                                    }

                                    HStack(spacing: 3) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 8))
                                        Text("Fused")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(Theme.gold)
                                    .padding(.leading, 12)
                                }
                            }
                        }

                        FlowLayout(spacing: 6) {
                            ForEach(analysis.detectedItems, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.visual)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Theme.visual.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        HStack(spacing: 6) {
                            Text(approachLabel(analysis.approach))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(approachColor(analysis.approach))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(approachColor(analysis.approach).opacity(0.08))
                                .clipShape(Capsule())

                            Text(analysis.setting)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Button {
                            HapticManager.light()
                            showAIReasoning = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("See the full story")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Theme.visual)
                        }
                    }
                }

                Theme.divider.frame(height: 1).padding(.horizontal, 20)
            }

            // Translation Matrix
            if !recipe.translationMatrix.isEmpty {
                detailRow(
                    icon: "arrow.left.arrow.right",
                    iconColor: Theme.primary,
                    title: "Visual to culinary mapping",
                    sectionKey: "matrix"
                ) {
                    VStack(spacing: 8) {
                        ForEach(recipe.translationMatrix, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Text(item.visual)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.visual)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textQuaternary)

                                Text(item.culinary)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.culinary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if item != recipe.translationMatrix.last {
                                Theme.divider.frame(height: 1)
                            }
                        }
                    }
                }

                Theme.divider.frame(height: 1).padding(.horizontal, 20)
            }

            // Plating
            if !recipe.platingSteps.isEmpty {
                detailRow(
                    icon: "paintpalette",
                    iconColor: Theme.primary,
                    title: "Plating & presentation",
                    sectionKey: "plating"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(recipe.platingSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                    .frame(width: 20)
                                Text(step)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineSpacing(3)
                            }
                        }
                    }
                }

                Theme.divider.frame(height: 1).padding(.horizontal, 20)
            }

            // Pairings
            detailRow(
                icon: "wineglass",
                iconColor: Theme.primary,
                title: "What to drink",
                sectionKey: "pairings"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    pairingRow(icon: "wineglass", title: "Wine", text: recipe.sommelierPairing.wine)
                    pairingRow(icon: "cup.and.saucer", title: "Cocktail", text: recipe.sommelierPairing.cocktail)
                    pairingRow(icon: "leaf", title: "Non-Alcoholic", text: recipe.sommelierPairing.nonalcoholic)
                }
            }

            // Methods & Techniques
            if recipe.components.contains(where: { !$0.method.isEmpty }) {
                Theme.divider.frame(height: 1).padding(.horizontal, 20)

                detailRow(
                    icon: "flame",
                    iconColor: Theme.culinary,
                    title: "Methods & techniques",
                    sectionKey: "techniques"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(recipe.components, id: \.self) { component in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(component.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(component.method)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineSpacing(3)
                            }

                            if component != recipe.components.last {
                                Theme.divider.frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .lightCard(padding: false)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Detail Row (expandable)

    private func detailRow<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        sectionKey: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedSections.contains(sectionKey) {
                        expandedSections.remove(sectionKey)
                    } else {
                        expandedSections.insert(sectionKey)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(iconColor)
                        .frame(width: 24)

                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textQuaternary)
                        .rotationEffect(.degrees(expandedSections.contains(sectionKey) ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            if expandedSections.contains(sectionKey) {
                content()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
    }

    private var totalIngredientCount: Int {
        recipe.components.reduce(0) { $0 + $1.ingredients.count }
    }

    private func scaledIngredient(_ ingredient: String) -> String {
        let parsed = IngredientParser.parse(ingredient)
        return parsed.scaled(from: recipe.baseServings, to: servingCount)
    }

    private func scaledNutrient(_ baseValue: Int) -> Int {
        guard recipe.baseServings > 0 else { return baseValue }
        return Int(Double(baseValue) * Double(servingCount) / Double(recipe.baseServings))
    }

    private func approachLabel(_ approach: String) -> String {
        switch approach {
        case "ingredient-driven": return "Built from real ingredients"
        case "hybrid": return "Ingredients + visual inspiration"
        default: return "Inspired by visual elements"
        }
    }

    private func approachColor(_ approach: String) -> Color {
        switch approach {
        case "ingredient-driven": return Theme.culinary
        case "hybrid": return Theme.primary
        default: return Theme.visual
        }
    }

    private func pairingRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.primary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            }
        }
    }
}
