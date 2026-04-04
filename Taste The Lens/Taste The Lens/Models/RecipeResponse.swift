import Foundation

/// The Codable response shape returned by the analyze-image edge function.
/// Matches the JSON schema produced by both Gemini and Claude providers.
struct ClaudeRecipeResponse: Codable, Sendable {
    let dishName: String
    let description: String
    let sceneAnalysis: SceneAnalysis?
    let colorPalette: [String]?
    let imageGenerationPrompt: String
    let translationMatrix: [TranslationItem]
    let components: [RecipeComponent]
    let cookingInstructions: [String]?
    let cookingSteps: [CookingStep]?
    let platingSteps: [String]
    let sommelierPairing: SommelierPairing
    let baseServings: Int?
    let estimatedCalories: Int?
    let nutrition: NutritionInfo?
    let prepTime: String?
    let cookTime: String?
    let difficulty: String?
    let chefCommentary: String?

    enum CodingKeys: String, CodingKey {
        case dishName = "dish_name"
        case description
        case sceneAnalysis = "scene_analysis"
        case colorPalette = "color_palette"
        case imageGenerationPrompt = "image_generation_prompt"
        case translationMatrix = "translation_matrix"
        case components
        case cookingInstructions = "cooking_instructions"
        case cookingSteps = "cooking_steps"
        case platingSteps = "plating_steps"
        case sommelierPairing = "sommelier_pairing"
        case baseServings = "base_servings"
        case estimatedCalories = "estimated_calories"
        case nutrition
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case difficulty
        case chefCommentary = "chef_commentary"
    }
}
