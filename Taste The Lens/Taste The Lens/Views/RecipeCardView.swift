import SwiftUI
import SwiftData

extension Notification.Name {
    static let reimagineRecipe = Notification.Name("reimagineRecipe")
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
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep: Int = 0
    @State private var checkedIngredients: Set<String> = []
    @State private var expandedSubstitutions: Set<String> = []
    @State private var expandedSections: Set<String> = []
    @State private var servingCount: Int = 2
    @State private var showAIReasoning = false
    @State private var showAuthPrompt = false
    @AppStorage("hasSeenAuthPrompt") private var hasSeenAuthPrompt = false

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
                    CompletionStep(recipe: recipe)
                        .tag(totalSteps - 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)

                // Bottom navigation bar
                StepNavigationBar(currentStep: $currentStep, totalSteps: totalSteps)
            }
        }
        .onAppear {
            servingCount = recipe.baseServings
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
        .sheet(isPresented: $showAIReasoning) {
            AIReasoningView(recipe: recipe)
        }
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
