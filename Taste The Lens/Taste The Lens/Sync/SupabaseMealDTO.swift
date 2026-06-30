import Foundation

/// The full meal recipe stored in the `meal_plan_meals.data` jsonb column.
/// Reuses the same building blocks as Recipe (RecipeComponent / CookingStep / NutritionInfo).
struct PlannedMealContent: Codable {
    let description: String
    let researchNotes: String
    let sources: [String]
    let prepTime: String?
    let cookTime: String?
    let difficulty: String?
    let colorPalette: [String]
    let imageGenerationPrompt: String
    let components: [RecipeComponent]
    let cookingSteps: [CookingStep]
    let nutrition: NutritionInfo?
    let sortIndex: Int
}

/// Codable DTO mirroring the Supabase `meal_plan_meals` table.
struct SupabaseMealDTO: Codable {
    let id: String?
    let mealPlanId: String
    let day: Int
    let mealType: String
    let dishName: String?
    let data: PlannedMealContent
    let imagePath: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mealPlanId = "meal_plan_id"
        case day
        case mealType = "meal_type"
        case dishName = "dish_name"
        case data
        case imagePath = "image_path"
        case createdAt = "created_at"
    }

    static func from(meal: PlannedMeal, mealPlanId: String, imagePath: String?) -> SupabaseMealDTO {
        let content = PlannedMealContent(
            description: meal.mealDescription,
            researchNotes: meal.researchNotes,
            sources: meal.sources,
            prepTime: meal.prepTime,
            cookTime: meal.cookTime,
            difficulty: meal.difficulty,
            colorPalette: meal.colorPalette,
            imageGenerationPrompt: meal.imageGenerationPrompt,
            components: meal.components,
            cookingSteps: meal.cookingSteps,
            nutrition: meal.nutrition,
            sortIndex: meal.sortIndex
        )
        return SupabaseMealDTO(
            id: meal.remoteId,
            mealPlanId: mealPlanId,
            day: meal.day,
            mealType: meal.mealType,
            dishName: meal.dishName,
            data: content,
            imagePath: imagePath,
            createdAt: nil
        )
    }

    /// Build a transient (not-inserted) PlannedMeal from the DTO + downloaded image.
    func toPlannedMeal(imageData: Data?) -> PlannedMeal {
        let meal = PlannedMeal(
            day: day,
            mealType: mealType,
            sortIndex: data.sortIndex,
            dishName: dishName ?? "",
            mealDescription: data.description,
            researchNotes: data.researchNotes,
            sources: data.sources,
            prepTime: data.prepTime,
            cookTime: data.cookTime,
            difficulty: data.difficulty,
            colorPalette: data.colorPalette,
            imageGenerationPrompt: data.imageGenerationPrompt,
            components: data.components,
            cookingSteps: data.cookingSteps,
            nutrition: data.nutrition
        )
        meal.remoteId = id
        if let imageData {
            meal.generatedImageData = imageData
            meal.imageGenerated = true
        }
        return meal
    }
}
