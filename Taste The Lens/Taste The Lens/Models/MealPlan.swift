import SwiftData
import Foundation
import UIKit

/// A complete AI-generated weekly meal plan: a set of planned meals plus a
/// consolidated grocery list. Reuses the same Codable building blocks as Recipe
/// (RecipeComponent, CookingStep, NutritionInfo) so meals render with the
/// existing recipe UI components.
@Model
final class MealPlan {
    var id: UUID
    var title: String
    var chefPersonality: String?
    var daysCount: Int
    var mealsPerDay: Int
    var groceryList: [GroceryItem]
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.plan)
    var meals: [PlannedMeal]

    // Sync & auth fields (mirror Recipe)
    var remoteId: String?
    var syncStatus: String = "local"
    var isDeleted: Bool = false
    var updatedAt: Date = Date()
    var userId: String?

    /// Personal bookmark — local only (not synced).
    var isFavorite: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        chefPersonality: String? = nil,
        daysCount: Int,
        mealsPerDay: Int,
        groceryList: [GroceryItem] = [],
        meals: [PlannedMeal] = [],
        userId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.chefPersonality = chefPersonality
        self.daysCount = max(1, daysCount)
        self.mealsPerDay = max(1, mealsPerDay)
        self.groceryList = groceryList
        self.meals = meals
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = userId
    }

    /// Meals grouped and sorted by day (1-based).
    var mealsByDay: [(day: Int, meals: [PlannedMeal])] {
        let grouped = Dictionary(grouping: meals, by: { $0.day })
        return grouped.keys.sorted().map { day in
            (day, grouped[day]!.sorted { $0.sortIndex < $1.sortIndex })
        }
    }

    var totalMealCount: Int { meals.count }
}

/// A single meal within a MealPlan — a full recipe plus research provenance and
/// an optional generated image (generated lazily, costs 1 credit).
@Model
final class PlannedMeal {
    var id: UUID
    var day: Int
    var mealType: String
    /// Stable ordering within a day (Breakfast < Lunch < Dinner < Snack).
    var sortIndex: Int

    var dishName: String
    var mealDescription: String
    var researchNotes: String
    var sources: [String]

    var prepTime: String?
    var cookTime: String?
    var difficulty: String?
    var colorPalette: [String]
    var imageGenerationPrompt: String

    var components: [RecipeComponent]
    var cookingSteps: [CookingStep]
    var nutrition: NutritionInfo?

    @Attribute(.externalStorage) var generatedImageData: Data?
    var imageGenerated: Bool = false

    /// Personal bookmark — local only (not synced).
    var isFavorite: Bool = false
    /// Server id once this meal's plan has been shared/synced (for per-meal deep links).
    var remoteId: String?

    var createdAt: Date
    var plan: MealPlan?

    init(
        id: UUID = UUID(),
        day: Int,
        mealType: String,
        sortIndex: Int = 0,
        dishName: String,
        mealDescription: String,
        researchNotes: String = "",
        sources: [String] = [],
        prepTime: String? = nil,
        cookTime: String? = nil,
        difficulty: String? = nil,
        colorPalette: [String] = [],
        imageGenerationPrompt: String = "",
        components: [RecipeComponent] = [],
        cookingSteps: [CookingStep] = [],
        nutrition: NutritionInfo? = nil
    ) {
        self.id = id
        self.day = day
        self.mealType = mealType
        self.sortIndex = sortIndex
        self.dishName = dishName
        self.mealDescription = mealDescription
        self.researchNotes = researchNotes
        self.sources = sources
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.difficulty = difficulty
        self.colorPalette = colorPalette
        self.imageGenerationPrompt = imageGenerationPrompt
        self.components = components
        self.cookingSteps = cookingSteps
        self.nutrition = nutrition
        self.createdAt = Date()
    }

    var generatedImage: UIImage? {
        guard let data = generatedImageData else { return nil }
        return UIImage(data: data)
    }
}

/// A consolidated grocery-list item, aisle-grouped.
struct GroceryItem: Codable, Hashable, Identifiable {
    var name: String
    var quantity: String
    var aisle: String

    var id: String { "\(aisle)|\(name)|\(quantity)" }
}
