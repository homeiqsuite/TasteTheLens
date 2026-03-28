import Foundation

/// Codable DTO mirroring the Supabase `recipes` table schema.
/// Used for serializing/deserializing between local Recipe model and Supabase.
struct SupabaseRecipeDTO: Codable {
    let id: String?
    let userId: String
    let dishName: String
    let description: String?
    let colorPalette: [String]?
    let translationMatrix: [TranslationItem]?
    let components: [RecipeComponent]?
    let cookingInstructions: [String]?
    let cookingSteps: [CookingStep]?
    let platingSteps: [String]?
    let sommelierPairing: SommelierPairing?
    let sceneAnalysis: SceneAnalysis?
    let inspirationImagePath: String?
    let dishImagePath: String?
    let chefPersonality: String?
    let rawResponse: String?
    let isDeleted: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dishName = "dish_name"
        case description
        case colorPalette = "color_palette"
        case translationMatrix = "translation_matrix"
        case components
        case cookingInstructions = "cooking_instructions"
        case cookingSteps = "cooking_steps"
        case platingSteps = "plating_steps"
        case sommelierPairing = "sommelier_pairing"
        case sceneAnalysis = "scene_analysis"
        case inspirationImagePath = "inspiration_image_path"
        case dishImagePath = "dish_image_path"
        case chefPersonality = "chef_personality"
        case rawResponse = "raw_response"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Create a DTO from a local Recipe for uploading to Supabase.
    static func from(recipe: Recipe, userId: String, inspirationPath: String?, dishImagePath: String?) -> SupabaseRecipeDTO {
        SupabaseRecipeDTO(
            id: recipe.remoteId,
            userId: userId,
            dishName: recipe.dishName,
            description: recipe.recipeDescription,
            colorPalette: recipe.colorPalette,
            translationMatrix: recipe.translationMatrix,
            components: recipe.components,
            cookingInstructions: recipe.cookingInstructions,
            cookingSteps: recipe.cookingSteps,
            platingSteps: recipe.platingSteps,
            sommelierPairing: recipe.sommelierPairing,
            sceneAnalysis: recipe.sceneAnalysis,
            inspirationImagePath: inspirationPath,
            dishImagePath: dishImagePath,
            chefPersonality: recipe.chefPersonality,
            rawResponse: recipe.claudeRawResponse,
            isDeleted: recipe.isDeleted,
            createdAt: nil,
            updatedAt: nil
        )
    }

    /// Convert a Supabase DTO to a local Recipe.
    func toRecipe(inspirationData: Data, dishImageData: Data?) -> Recipe {
        let recipe = Recipe(
            dishName: dishName,
            recipeDescription: description ?? "",
            colorPalette: colorPalette ?? [],
            inspirationImageData: inspirationData,
            generatedDishImageData: dishImageData,
            generatedDishImageURL: dishImagePath ?? "",
            translationMatrix: translationMatrix ?? [],
            components: components ?? [],
            cookingInstructions: cookingInstructions ?? [],
            platingSteps: platingSteps ?? [],
            sommelierPairing: sommelierPairing ?? SommelierPairing(wine: "", cocktail: "", nonalcoholic: ""),
            sceneAnalysis: sceneAnalysis,
            claudeRawResponse: rawResponse ?? "",
            chefPersonality: chefPersonality,
            cookingSteps: cookingSteps ?? []
        )
        recipe.remoteId = id
        recipe.syncStatus = "synced"
        recipe.userId = userId
        return recipe
    }
}
