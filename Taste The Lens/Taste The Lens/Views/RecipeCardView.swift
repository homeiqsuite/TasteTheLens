import SwiftUI
import SwiftData

extension Notification.Name {
    static let reimagineRecipe = Notification.Name("reimagineRecipe")
    static let simplifyRecipe = Notification.Name("simplifyRecipe")
}

enum ReimagineCourseType: String, CaseIterable, Identifiable {
    case appetizer
    case dessert
    case drink
    case sideDish = "side dish"
    case soup
    case salad
    case breakfast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appetizer: return "Appetizer"
        case .dessert: return "Dessert"
        case .drink: return "Drink"
        case .sideDish: return "Side Dish"
        case .soup: return "Soup"
        case .salad: return "Salad"
        case .breakfast: return "Breakfast"
        }
    }

    var icon: String {
        switch self {
        case .appetizer: return "fork.knife"
        case .dessert: return "birthday.cake"
        case .drink: return "wineglass"
        case .sideDish: return "leaf"
        case .soup: return "mug"
        case .salad: return "carrot"
        case .breakfast: return "sun.horizon"
        }
    }
}

struct RecipeCardView: View {
    let recipe: Recipe
    var isOnboardingFlow: Bool = false
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep: Int = 0
    @State private var checkedIngredients: Set<String> = []
    @State private var expandedSubstitutions: Set<String> = []
    @State private var expandedSections: Set<String> = []
    @State private var servingCount: Int = 2
    @State private var showAIReasoning = false
    @State private var showAuthPrompt = false
    @State private var showCelebration = false
    @State private var showMilestoneToast = false
    @State private var milestoneMessage = ""
    @AppStorage("hasSeenAuthPrompt") private var hasSeenAuthPrompt = false
    @AppStorage("hasGeneratedFirstRecipe") private var hasGeneratedFirstRecipe = false
    @AppStorage("hasSeenMilestone3") private var hasSeenMilestone3 = false
    @AppStorage("hasSeenMilestone5") private var hasSeenMilestone5 = false
    @AppStorage("hasSeenRecipeWalkthrough") private var hasSeenRecipeWalkthrough = false
    @State private var walkthroughStep: Int? = nil
    @State private var showCookingMode = false
    @State private var overlayTask: Task<Void, Never>?

    private var cookingSteps: [CookingStep] {
        recipe.effectiveCookingSteps
    }

    private var totalSteps: Int {
        // Step 0 (Prep) + cooking steps + Step N (Completion)
        2 + cookingSteps.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Persistent hero image
                CompactHeroView(recipe: recipe)

                // Step indicator
                StepIndicatorBar(totalSteps: totalSteps, currentStep: $currentStep)

                // Step content
                TabView(selection: $currentStep) {
                    // Step 0: Prep overview
                    PrepOverviewStep(
                        recipe: recipe,
                        checkedIngredients: $checkedIngredients,
                        expandedSubstitutions: $expandedSubstitutions,
                        expandedSections: $expandedSections,
                        servingCount: $servingCount,
                        showAIReasoning: $showAIReasoning
                    )
                    .tag(0)

                    // Steps 1-N: Cooking steps
                    ForEach(Array(cookingSteps.enumerated()), id: \.offset) { index, step in
                        CookingStepView(
                            recipe: recipe,
                            stepIndex: index,
                            cookingStep: step,
                            checkedIngredients: $checkedIngredients,
                            servingCount: $servingCount
                        )
                        .tag(index + 1)
                    }

                    // Final step: Completion
                    CompletionStep(recipe: recipe, servingCount: servingCount)
                        .tag(totalSteps - 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator dots
                PageIndicatorView(totalSteps: totalSteps, currentStep: currentStep)
                    .padding(.vertical, 8)

                // Bottom navigation bar
                StepNavigationBar(
                    currentStep: $currentStep,
                    totalSteps: totalSteps,
                    onCookingMode: (currentStep > 0 && currentStep < totalSteps - 1) ? { showCookingMode = true } : nil
                )
            }

            // First-recipe celebration overlay
            if showCelebration {
                ConfettiView()
                    .ignoresSafeArea()

                // Toast message
                VStack {
                    celebrationToast
                    Spacer()
                }
                .transition(.opacity)
            }

            // Milestone toast
            if showMilestoneToast {
                VStack {
                    milestoneToastView
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            servingCount = max(1, min(99, recipe.baseServings))
            let isFirstRecipe = !hasGeneratedFirstRecipe
            overlayTask?.cancel()
            overlayTask = Task {
                if isFirstRecipe {
                    hasGeneratedFirstRecipe = true
                    try? await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { return }
                    HapticManager.success()
                    withAnimation(.easeOut(duration: 0.4)) { showCelebration = true }
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.5)) { showCelebration = false }
                    // sequence continues in .onChange(of: showCelebration)
                } else {
                    let recipeCount = UserDefaults.standard.integer(forKey: "totalRecipeCount")
                    let hasMilestone: Bool
                    if recipeCount >= 5 && !hasSeenMilestone5 {
                        hasSeenMilestone5 = true
                        milestoneMessage = "5 recipes! Invite friends to a Tasting Menu"
                        hasMilestone = true
                    } else if recipeCount >= 3 && !hasSeenMilestone3 {
                        hasSeenMilestone3 = true
                        milestoneMessage = "3 dishes created — try a Challenge!"
                        hasMilestone = true
                    } else {
                        hasMilestone = false
                    }

                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }

                    if hasMilestone {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showMilestoneToast = true }
                        try? await Task.sleep(for: .seconds(4))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.3)) { showMilestoneToast = false }
                        // sequence continues in .onChange(of: showMilestoneToast)
                    } else if !hasSeenAuthPrompt && !AuthManager.shared.isAuthenticated {
                        showAuthPrompt = true
                        hasSeenAuthPrompt = true
                    }
                }
            }
        }
        .onDisappear {
            overlayTask?.cancel()
            overlayTask = nil
        }
        .onChange(of: showCelebration) { oldValue, newValue in
            guard oldValue && !newValue else { return }
            overlayTask?.cancel()
            overlayTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                if !hasSeenAuthPrompt && !AuthManager.shared.isAuthenticated {
                    showAuthPrompt = true
                    hasSeenAuthPrompt = true
                }
            }
        }
        .onChange(of: showMilestoneToast) { oldValue, newValue in
            guard oldValue && !newValue else { return }
            overlayTask?.cancel()
            overlayTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                if !hasSeenAuthPrompt && !AuthManager.shared.isAuthenticated {
                    showAuthPrompt = true
                    hasSeenAuthPrompt = true
                }
            }
        }
        .onChange(of: walkthroughStep) { oldValue, newValue in
            guard oldValue != nil && newValue == nil && hasSeenRecipeWalkthrough else { return }
            overlayTask?.cancel()
            overlayTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                if !hasSeenAuthPrompt && !AuthManager.shared.isAuthenticated {
                    showAuthPrompt = true
                    hasSeenAuthPrompt = true
                }
            }
        }
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptSheet()
        }
        .sheet(isPresented: $showAIReasoning) {
            AIReasoningView(recipe: recipe)
        }
        .fullScreenCover(isPresented: $showCookingMode) {
            CookingModeView(recipe: recipe, servingCount: servingCount)
        }
    }

    // MARK: - Celebration Toast

    private var celebrationToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "party.popper")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text("Your first dish! You're a natural.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Theme.cardSurface)
                .overlay(
                    Capsule()
                        .stroke(Theme.gold.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.top, 60)
    }

    // MARK: - Milestone Toast

    private var milestoneToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text(milestoneMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.top, 60)
    }

    // MARK: - Recipe Walkthrough

    private let walkthroughSteps = [
        (text: "Swipe left to see cooking steps", icon: "hand.draw", pointer: TooltipPointer.down),
    ]

    // Vertical positions (as fraction of screen height) to anchor each tooltip
    private let walkthroughAnchors: [CGFloat] = [
        0.55,  // Step 0: Near the step indicator / top of content
    ]

    private func walkthroughOverlay(step: Int) -> some View {
        VStack(spacing: 0) {
            // Skip button — top trailing (hidden for onboarding flow)
            if !isOnboardingFlow {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { walkthroughStep = nil }
                        hasSeenRecipeWalkthrough = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.25))
                            )
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
            } else {
                Color.clear.frame(height: 16)
            }

            Spacer()

            // Positioned tooltip anchor
            GeometryReader { proxy in
                let anchorY = proxy.size.height * walkthroughAnchors[step]

                VStack(spacing: 0) {
                    if walkthroughSteps[step].pointer == .down {
                        Spacer()
                            .frame(height: anchorY)
                        CoachTooltip(
                            text: walkthroughSteps[step].text,
                            icon: walkthroughSteps[step].icon,
                            pointer: walkthroughSteps[step].pointer,
                            autoDismissSeconds: 8
                        ) {
                            advanceWalkthrough()
                        }
                        .id(step)
                    } else {
                        CoachTooltip(
                            text: walkthroughSteps[step].text,
                            icon: walkthroughSteps[step].icon,
                            pointer: walkthroughSteps[step].pointer,
                            autoDismissSeconds: 8
                        ) {
                            advanceWalkthrough()
                        }
                        .id(step)
                        Spacer()
                            .frame(height: proxy.size.height - anchorY - 60)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func advanceWalkthrough() {
        guard let step = walkthroughStep else { return }
        let nextStep = step + 1
        if nextStep < walkthroughSteps.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                walkthroughStep = nextStep
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                walkthroughStep = nil
            }
            hasSeenRecipeWalkthrough = true
        }
    }

}

// MARK: - Page Indicator

private struct PageIndicatorView: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Theme.primary : Theme.cardBorder)
                    .frame(width: index == currentStep ? 16 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
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
        cookingInstructions: [],
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
        claudeRawResponse: "",
        cookingSteps: [
            CookingStep(instruction: "Prepare the citrus puree: Peel and roughly chop 3 carrots. Roast at 400°F for 25 minutes until caramelized and tender. Transfer to a blender with the juice and zest of 1 orange and 1 tbsp honey. Blend until silky smooth.", ingredientsUsed: ["3 carrots", "1 orange, zested & juiced", "1 tbsp honey"]),
            CookingStep(instruction: "While the carrots roast, pat the scallops completely dry with paper towels — this is critical for a good sear. Season both sides generously with salt and pepper.", ingredientsUsed: ["6 large scallops", "1 tsp salt & pepper"]),
            CookingStep(instruction: "Heat a heavy skillet over high heat. Add 2 tbsp butter and swirl. Once the butter foams and just begins to brown, place scallops in the pan. Sear for 2 minutes per side until a deep golden crust forms. Do not move them during searing.", ingredientsUsed: ["2 tbsp butter"]),
            CookingStep(instruction: "Plate immediately: swoosh the warm citrus puree across the center of a dark plate. Place 3 scallops per serving atop the puree, golden side up. Drizzle with chive oil and garnish with micro herbs.", ingredientsUsed: []),
        ]
    )

    NavigationStack {
        RecipeCardView(recipe: recipe)
    }
    .modelContainer(for: Recipe.self, inMemory: true)
}
