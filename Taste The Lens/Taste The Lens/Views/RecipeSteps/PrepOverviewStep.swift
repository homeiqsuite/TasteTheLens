import SwiftUI

// MARK: - Scroll Offset Tracking

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Section Appear Modifier

private struct SectionAppearModifier: ViewModifier {
    let sectionKey: String
    @Binding var appeared: Set<String>

    func body(content: Content) -> some View {
        content
            .opacity(appeared.contains(sectionKey) ? 1 : 0)
            .offset(y: appeared.contains(sectionKey) ? 0 : 16)
            .onAppear {
                guard !appeared.contains(sectionKey) else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    appeared.insert(sectionKey)
                }
            }
    }
}

private extension View {
    func sectionAppearAnimation(key: String, appeared: Binding<Set<String>>) -> some View {
        modifier(SectionAppearModifier(sectionKey: key, appeared: appeared))
    }
}

// MARK: - PrepOverviewStep

struct PrepOverviewStep: View {
    let recipe: Recipe
    @Binding var checkedIngredients: Set<String>
    @Binding var expandedSubstitutions: Set<String>
    @Binding var expandedSections: Set<String>
    @Binding var servingCount: Int
    @Binding var showAIReasoning: Bool
    @Binding var currentStep: Int
    @State private var contentMode: PrepContentMode = .quickStart
    @State private var showFullDescription: Bool = false
    @State private var showAIBreakdown: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var expandedComponents: Set<String> = []
    @State private var sectionAppeared: Set<String> = []
    @State private var highlightedTranslation: Int? = nil
    @State private var isGeneratingShoppingList = false
    @State private var showSubstitutionSheet = false
    @State private var substitutionSheetIngredient: String = ""
    @State private var substitutionSheetSubs: [String] = []
    @State private var showAIReasoningTooltip = false
    @AppStorage("hasSeenAIReasoningTooltip") private var hasSeenAIReasoningTooltip = false

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Scroll offset tracker
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("prepScroll")).minY
                            )
                    }
                    .frame(height: 0)

                    // === Stats strip — always first, right below step indicators ===
                    quickStatsStrip

                    // === Mode picker + dynamic content area ===
                    prepModePickerSection

                    // Mode-specific content (directly below pills so users see it change)
                    if contentMode == .storyMode {
                        storySection
                            .sectionAppearAnimation(key: "story", appeared: $sectionAppeared)
                    } else if contentMode == .aiBreakdown {
                        aiBreakdownSection
                            .sectionAppearAnimation(key: "ai", appeared: $sectionAppeared)
                    }

                    inlineCTA

                    chapterSpacer

                    // === Ingredients ===
                    ingredientComponentCards
                        .sectionAppearAnimation(key: "ingredients", appeared: $sectionAppeared)

                    chapterSpacer

                    // === CHAPTER 5: Full details ===
                    nutritionSection
                        .sectionAppearAnimation(key: "nutrition", appeared: $sectionAppeared)
                    moreDetailsSection
                        .sectionAppearAnimation(key: "details", appeared: $sectionAppeared)

                    Spacer().frame(height: 20)
                }
            }
            .coordinateSpace(name: "prepScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollOffset = $0 }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)

            // Sticky context header
            if scrollOffset < -120 {
                stickyContextHeader
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset < -120)
            }
        }
        .onChange(of: contentMode) { _, newMode in
            withAnimation(.easeInOut(duration: 0.3)) {
                switch newMode {
                case .quickStart:
                    showFullDescription = false
                    showAIBreakdown = false
                case .storyMode:
                    showFullDescription = true
                    showAIBreakdown = false
                case .aiBreakdown:
                    showFullDescription = false
                    showAIBreakdown = true
                }
            }
        }
        .onAppear {
            if !hasSeenAIReasoningTooltip {
                Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation { showAIReasoningTooltip = true }
                }
            }
        }
        .sheet(isPresented: $showSubstitutionSheet) {
            SubstitutionSheet(ingredient: substitutionSheetIngredient, substitutes: substitutionSheetSubs)
                .presentationDetents([.height(250)])
                .presentationBackground(Theme.background)
        }
    }

    // MARK: - Chapter Spacer

    private var chapterSpacer: some View {
        Rectangle()
            .fill(Theme.background)
            .frame(height: 40)
    }

    // MARK: - Sticky Context Header

    private var stickyContextHeader: some View {
        HStack(spacing: 6) {
            Text(recipe.dishName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            if let cook = recipe.cookTime, !cook.isEmpty {
                Text("·")
                    .foregroundStyle(Theme.textQuaternary)
                Text(cook)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            }

            if let difficulty = recipe.difficulty, !difficulty.isEmpty {
                Text("·")
                    .foregroundStyle(Theme.textQuaternary)
                Text(difficulty)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            Theme.cardSurface
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Chapter 1: Ultra-Lightweight Top

    private var prepModePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How do you want to start?")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)

            PrepModePicker(
                selectedMode: $contentMode,
                hasTranslationMatrix: !recipe.translationMatrix.isEmpty
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var inlineCTA: some View {
        Button {
            HapticManager.medium()
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep = 1
            }
        } label: {
            HStack(spacing: 8) {
                Text("Let's Cook")
                    .font(.system(size: 17, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Theme.darkTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.ctaGradient, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.gold.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Chapter 2: Ingredient Component Cards

    private var ingredientComponentCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Ingredients")
                Spacer()
                Text("\(checkedIngredients.count)/\(totalIngredientCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)

            ForEach(Array(recipe.components.enumerated()), id: \.offset) { index, component in
                IngredientComponentCard(
                    component: component,
                    accentColor: accentColor(for: index),
                    baseServings: recipe.baseServings,
                    checkedIngredients: $checkedIngredients,
                    servingCount: $servingCount,
                    isExpanded: expandedComponents.contains(component.name),
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if expandedComponents.contains(component.name) {
                                expandedComponents.remove(component.name)
                            } else {
                                expandedComponents.insert(component.name)
                            }
                        }
                    },
                    onSubstitution: { ingredient, subs in
                        substitutionSheetIngredient = ingredient
                        substitutionSheetSubs = subs
                        showSubstitutionSheet = true
                    }
                )
                .padding(.horizontal, 16)
            }

            // Shopping List button
            Button {
                HapticManager.medium()
                isGeneratingShoppingList = true
                DispatchQueue.main.async {
                    shareShoppingList()
                    isGeneratingShoppingList = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingShoppingList {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.primary)
                    } else {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 14))
                    }
                    Text("Shopping List")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.primary.opacity(0.2), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .background(Theme.cardSurface.opacity(0.5))
    }

    private func accentColor(for index: Int) -> Color {
        let palette = recipe.colorPalette.compactMap { Color(hex: $0) }
        if !palette.isEmpty {
            return palette[index % palette.count]
        }
        let fallback: [Color] = [Theme.primary, Theme.visual, Theme.culinary]
        return fallback[index % fallback.count]
    }

    // MARK: - Chapter 3: Story & Vibe

    @ViewBuilder
    private var storySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("The Vibe")

            Text(recipe.recipeDescription)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(5)
                .lineLimit(showFullDescription ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if recipe.recipeDescription.count > 100 {
                Button {
                    HapticManager.light()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFullDescription.toggle()
                    }
                } label: {
                    Text(showFullDescription ? "Show less" : "Expand vibe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }

            if showFullDescription {
                chefCommentarySection
                dietaryBadges
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Chef Commentary

    @ViewBuilder
    private var chefCommentarySection: some View {
        if let commentary = recipe.chefCommentary, !commentary.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: chefCommentaryIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 2)

                Text(commentary)
                    .font(.system(size: 15, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var chefCommentaryIcon: String {
        switch recipe.chefPersonality {
        case "dooby": return "moon.stars"
        case "beginner": return "leaf"
        case "grizzly": return "tree"
        case "familyChef": return "figure.2.and.child.holdinghands"
        default: return "quote.opening"
        }
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
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Chapter 4: AI Breakdown

    @ViewBuilder
    private var aiBreakdownSection: some View {
        if !recipe.translationMatrix.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Collapsible header
                Button {
                    HapticManager.light()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAIBreakdown.toggle()
                    }
                } label: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.visual)
                            Text("AI Flavor Mapping")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textQuaternary)
                            .rotationEffect(.degrees(showAIBreakdown ? 180 : 0))
                    }
                }

                if !showAIBreakdown {
                    Text("Tap any element from your photo to see its tasty transformation.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                }

                if showAIBreakdown {
                    translationMatrixContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.cardSurface.opacity(0.5))
        }
    }

    private var translationMatrixContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.primary)
                Text("How your photo became a recipe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(Array(recipe.translationMatrix.enumerated()), id: \.offset) { index, item in
                Button {
                    HapticManager.light()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        highlightedTranslation = highlightedTranslation == index ? nil : index
                    }
                } label: {
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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(highlightedTranslation == index ? Theme.gold.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(highlightedTranslation == index ? Theme.gold.opacity(0.2) : Color.clear, lineWidth: 0.5)
                    )
                }

                if index < recipe.translationMatrix.count - 1 {
                    Theme.divider.frame(height: 1)
                }
            }

            // See full story button
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
            .padding(.top, 4)

            if showAIReasoningTooltip {
                CoachTooltip(
                    text: "See how AI connected visuals to flavors",
                    icon: "sparkles",
                    pointer: .up
                ) {
                    showAIReasoningTooltip = false
                    hasSeenAIReasoningTooltip = true
                }
                .transition(.opacity)
            }
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

            // Difficulty
            if let difficulty = recipe.difficulty, !difficulty.isEmpty {
                dividerLine

                VStack(spacing: 1) {
                    Image(systemName: difficultyIcon(difficulty))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(difficultyColor(difficulty))
                    Text(difficulty)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Text("difficulty")
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

    private func scaledNutrient(_ baseValue: Int) -> Int {
        guard recipe.baseServings > 0 else { return baseValue }
        return Int(Double(baseValue) * Double(servingCount) / Double(recipe.baseServings))
    }

    private func shareShoppingList() {
        let text = ShoppingListGenerator.generate(from: recipe, servingCount: servingCount)
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController { presenter = presented }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }

    private func difficultyIcon(_ difficulty: String) -> String {
        switch difficulty {
        case "Easy": return "gauge.open.with.lines.needle.33percent"
        case "Advanced": return "gauge.open.with.lines.needle.84percent.exclamation"
        default: return "gauge.open.with.lines.needle.50percent"
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "Easy": return Theme.visual
        case "Advanced": return Theme.culinary
        default: return Theme.primary
        }
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
