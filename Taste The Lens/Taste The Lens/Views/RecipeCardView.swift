import SwiftUI
import SwiftData

extension Notification.Name {
    static let reimagineRecipe = Notification.Name("reimagineRecipe")
}

struct RecipeCardView: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @State private var exportImage: UIImage?
    @State private var heroAppeared = false
    @State private var isSaved = false
    @State private var checkedIngredients: Set<String> = []
    @State private var expandedSubstitutions: Set<String> = []
    @State private var expandedSections: Set<String> = []
    @State private var showAuthPrompt = false
    @State private var showCookingMode = false
    @State private var showAIReasoning = false
    @State private var showCreateChallenge = false
    @State private var isCreatingChallenge = false
    @State private var challengeError: String?
    @State private var servingCount: Int = 2
    @AppStorage("hasSeenAuthPrompt") private var hasSeenAuthPrompt = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // TIER 1: The Hero
                    heroImageSection

                    // TIER 2: The Essentials
                    descriptionSection
                    dietaryBadges
                    quickStatsStrip
                    ingredientsSection
                    stepsSection

                    // TIER 3: Deep Dive
                    moreDetailsSection

                    Spacer().frame(height: 100)
                }
            }
            .clipped()

            actionBar
        }
        .onAppear {
            servingCount = recipe.baseServings
            renderExportImage()
            if !hasSeenAuthPrompt && !AuthManager.shared.isAuthenticated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showAuthPrompt = true
                    hasSeenAuthPrompt = true
                }
            }
        }
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptSheet()
        }
        .fullScreenCover(isPresented: $showCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .sheet(isPresented: $showAIReasoning) {
            AIReasoningView(recipe: recipe)
        }
        .sheet(isPresented: $showCreateChallenge) {
            challengeConfirmationSheet
        }
    }

    // MARK: - Tier 1: Hero Image

    private var heroImageSection: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed generated dish image
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .offset(y: heroAppeared ? 0 : -30)
                    .opacity(heroAppeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: heroAppeared)
            }

            // Gradient scrim for text readability
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)

            // Overlay content
            HStack(alignment: .bottom) {
                // Dish name
                Text(recipe.dishName)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Spacer()

                // Approach badge
                if let analysis = recipe.sceneAnalysis {
                    Text(approachShortLabel(analysis.approach))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Source PIP thumbnail (top-right)
            if let uiImage = UIImage(data: recipe.inspirationImageData) {
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 6)
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                    Spacer()
                }
                .frame(height: 380)
            }
        }
        .onAppear { heroAppeared = true }
    }

    // MARK: - Tier 2: Description

    private var descriptionSection: some View {
        Text(recipe.recipeDescription)
            .font(.system(size: 15))
            .foregroundStyle(Theme.textSecondary)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
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

    // MARK: - Tier 2: Quick Stats Strip

    private var quickStatsStrip: some View {
        HStack(spacing: 0) {
            // Servings stepper
            HStack(spacing: 10) {
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

            dividerLine

            // Ingredient count
            VStack(spacing: 1) {
                Text("\(totalIngredientCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("ingredients")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)

            dividerLine

            // Step count
            VStack(spacing: 1) {
                Text("\(recipe.cookingInstructions.count)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("steps")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
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

    // MARK: - Tier 2: Ingredients

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

    // MARK: - Tier 2: Steps

    @ViewBuilder
    private var stepsSection: some View {
        if !recipe.cookingInstructions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Steps")

                ForEach(Array(recipe.cookingInstructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.darkTextPrimary)
                            .frame(width: 28, height: 28)
                            .background(Theme.primary)
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(4)
                            .padding(.top, 4)
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

    // MARK: - Tier 3: More Details

    private var moreDetailsSection: some View {
        VStack(spacing: 0) {
            // Scene Analysis
            if let analysis = recipe.sceneAnalysis, !analysis.detectedItems.isEmpty {
                detailRow(
                    icon: "eye",
                    iconColor: Theme.visual,
                    title: "How AI read your photo",
                    sectionKey: "scene"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
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

            // Methods & Techniques (from components)
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

    // MARK: - Detail Row (Tier 3 expandable)

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

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            // Share menu
            Menu {
                Button {
                    shareRecipeImage()
                } label: {
                    Label("Share Image", systemImage: "photo")
                }
                Button {
                    shareRecipePDF()
                } label: {
                    Label("Share PDF", systemImage: "doc")
                }
                Button {
                    reimagineRecipe()
                } label: {
                    Label("Reimagine", systemImage: "arrow.trianglehead.2.clockwise")
                }
                Divider()
                Button {
                    throwTheGauntlet()
                } label: {
                    Label("Throw the Gauntlet", systemImage: "flag.checkered")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 52, height: 48)
                    .background(Theme.buttonBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Cook button (primary CTA)
            Button {
                HapticManager.medium()
                showCookingMode = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                    Text("Cook")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.darkTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Save button
            Button {
                saveRecipe()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "checkmark" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isSaved ? "Saved" : "Save")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(isSaved ? Theme.darkTextPrimary : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isSaved ? Theme.primary : Theme.buttonBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Theme.cardSurface
                .overlay(
                    VStack { Theme.divider.frame(height: 1); Spacer() }
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: -2)
        )
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

    private func approachLabel(_ approach: String) -> String {
        switch approach {
        case "ingredient-driven": return "Built from real ingredients"
        case "hybrid": return "Ingredients + visual inspiration"
        default: return "Inspired by visual elements"
        }
    }

    private func approachShortLabel(_ approach: String) -> String {
        switch approach {
        case "ingredient-driven": return "Ingredient-driven"
        case "hybrid": return "Hybrid"
        default: return "Visual"
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

    // MARK: - Actions

    private func saveRecipe() {
        guard !isSaved else { return }
        modelContext.insert(recipe)
        try? modelContext.save()
        isSaved = true
        HapticManager.success()

        if AuthManager.shared.isAuthenticated {
            Task {
                await SyncManager.shared.syncRecipe(recipe)
            }
        }
    }

    private func reimagineRecipe() {
        guard UsageTracker.shared.canGenerate else {
            NotificationCenter.default.post(name: .reimagineRecipe, object: nil, userInfo: ["showPaywall": true])
            return
        }
        NotificationCenter.default.post(
            name: .reimagineRecipe,
            object: nil,
            userInfo: [
                "excludeDishName": recipe.dishName,
                "inspirationImageData": recipe.inspirationImageData
            ]
        )
    }

    private func throwTheGauntlet() {
        guard AuthManager.shared.isAuthenticated else {
            showAuthPrompt = true
            return
        }
        if !isSaved {
            saveRecipe()
        }
        showCreateChallenge = true
    }

    private var challengeConfirmationSheet: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.gold)

                    Text("Throw the Gauntlet")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("Challenge the community to cook **\(recipe.dishName)** and photograph their real-world attempt.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let challengeError {
                        Text(challengeError)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        Task {
                            isCreatingChallenge = true
                            challengeError = nil
                            do {
                                _ = try await ChallengeService.shared.createChallenge(recipe: recipe)
                                HapticManager.success()
                                showCreateChallenge = false
                            } catch {
                                challengeError = error.localizedDescription
                                HapticManager.error()
                            }
                            isCreatingChallenge = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isCreatingChallenge {
                                ProgressView().tint(Theme.darkBg)
                            }
                            Text(isCreatingChallenge ? "Publishing..." : "Publish Challenge")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Theme.darkBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isCreatingChallenge)
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showCreateChallenge = false }
                        .foregroundStyle(Theme.gold)
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func renderExportImage() {
        let renderer = ImageRenderer(content:
            SideBySideExportView(recipe: recipe)
                .frame(width: 1080, height: 1080)
        )
        renderer.scale = 3.0
        exportImage = renderer.uiImage
    }

    private func shareRecipeImage() {
        if exportImage == nil { renderExportImage() }
        guard let exportImage else { return }
        presentShareSheet(items: [exportImage])
    }

    private func shareRecipePDF() {
        let pdfData = PDFExporter.generatePDF(for: recipe)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(recipe.dishName).pdf")
        try? pdfData.write(to: tempURL)
        presentShareSheet(items: [tempURL])
    }

    private func presentShareSheet(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }
}

// MARK: - Component Card (used in Tier 3 Techniques)

struct ComponentCard: View {
    let component: RecipeComponent
    let gold: Color
    var baseServings: Int = 2
    var targetServings: Int = 2
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(component.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textQuaternary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    FlowLayout(spacing: 6) {
                        ForEach(component.ingredients, id: \.self) { ingredient in
                            let parsed = IngredientParser.parse(ingredient)
                            Text(parsed.scaled(from: baseServings, to: targetServings))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.background)
                                .clipShape(Capsule())
                        }
                    }

                    Text(component.method)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                        .lineSpacing(3)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

// Simple flow layout for ingredient tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        let maxWidth = proposal.width ?? .infinity
        for (index, position) in result.positions.enumerated() {
            let itemWidth = min(subviews[index].sizeThatFits(.unspecified).width, maxWidth)
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(width: itemWidth, height: nil)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let clampedWidth = min(size.width, maxWidth)
            if currentX + clampedWidth > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            let clampedSize = subview.sizeThatFits(ProposedViewSize(width: clampedWidth, height: nil))
            lineHeight = max(lineHeight, clampedSize.height)
            currentX += clampedWidth + spacing
            totalHeight = currentY + lineHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        return renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        }
    }()
    let imageData = sampleImage.jpegData(compressionQuality: 0.8)!

    let recipe = Recipe(
        dishName: "Syntax of Zest: A Modern Scallop & Citrus Composition",
        recipeDescription: "Inspired by the vibrant energy and precise structure of a digital workspace, this dish translates the sharp contrasts of glowing screens and organized code into a symphony of flavors.",
        inspirationImageData: imageData,
        generatedDishImageData: imageData,
        generatedDishImageURL: "",
        translationMatrix: [
            TranslationItem(visual: "Dominant orange hue from Gatorade cap and screen element (#FF8C00)", culinary: "Roasted Carrot & Orange Zest Puree — sweet, earthy, vibrant"),
            TranslationItem(visual: "Bright lime green from Gatorade glow (#00FF00)", culinary: "Vibrant Lime & Chive Oil — fresh, zesty, herbaceous"),
            TranslationItem(visual: "Dark grey/black background of desk mat", culinary: "Black Sesame Tuiles — savory, nutty, dramatic"),
        ],
        components: [
            RecipeComponent(name: "Seared Scallops", ingredients: ["6 large scallops", "2 tbsp butter", "1 tsp salt & pepper"], method: "Pat scallops dry. Season generously. Sear in hot butter for 2 minutes per side until golden.", substitutions: [
                IngredientSubstitution(original: "6 large scallops", substitutes: ["1 lb large shrimp", "1 block firm tofu"]),
                IngredientSubstitution(original: "2 tbsp butter", substitutes: ["2 tbsp olive oil"]),
            ]),
            RecipeComponent(name: "Citrus Puree", ingredients: ["3 carrots", "1 orange, zested & juiced", "1 tbsp honey"], method: "Roast carrots until caramelized. Blend with orange juice, zest, and honey until smooth.", substitutions: [
                IngredientSubstitution(original: "3 carrots", substitutes: ["2 sweet potatoes"]),
                IngredientSubstitution(original: "1 tbsp honey", substitutes: ["1 tbsp maple syrup", "1 tbsp agave nectar"]),
            ]),
        ],
        cookingInstructions: [
            "Prepare the citrus puree and let it cool slightly.",
            "Sear the scallops in a hot pan with butter until golden on each side.",
            "Drizzle the chive oil around the plate in a free-form pattern.",
        ],
        platingSteps: [
            "Spoon citrus puree in a swoosh across the center of a dark plate.",
            "Place scallops atop the puree.",
            "Garnish with micro herbs and edible flowers.",
        ],
        sommelierPairing: SommelierPairing(
            wine: "Sancerre — crisp, mineral, citrus-forward",
            cocktail: "Yuzu Gimlet with thyme",
            nonalcoholic: "Sparkling water with orange blossom and rosemary"
        ),
        sceneAnalysis: SceneAnalysis(
            detectedItems: ["Gatorade bottle", "desk lamp", "mechanical keyboard", "monitor with code editor", "dark desk mat"],
            detectedText: ["Gatorade"],
            setting: "Developer desk setup, warm ambient lighting",
            approach: "visual-translation"
        ),
        claudeRawResponse: ""
    )

    NavigationStack {
        RecipeCardView(recipe: recipe)
    }
    .modelContainer(for: Recipe.self, inMemory: true)
}
