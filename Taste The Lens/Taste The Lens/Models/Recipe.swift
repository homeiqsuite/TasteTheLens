import SwiftData
import Foundation
import UIKit

@Model
final class Recipe {
    var id: UUID
    var dishName: String
    var recipeDescription: String
    var colorPalette: [String]
    @Attribute(.externalStorage) var inspirationImageData: Data
    @Attribute(.externalStorage) var generatedDishImageData: Data?
    var generatedDishImageURL: String
    var translationMatrix: [TranslationItem]
    var components: [RecipeComponent]
    var cookingInstructions: [String]
    var platingSteps: [String]
    var sommelierPairing: SommelierPairing
    var sceneAnalysis: SceneAnalysis?
    var createdAt: Date
    var claudeRawResponse: String

    // Beta: sync & auth fields
    var remoteId: String?
    var syncStatus: String = "local"
    var isDeleted: Bool = false
    var updatedAt: Date = Date()
    var userId: String?
    var chefPersonality: String?
    var baseServings: Int = 2
    var estimatedCalories: Int?
    var nutrition: NutritionInfo?
    var prepTime: String?
    var cookTime: String?
    var difficulty: String?
    var chefCommentary: String?

    // Step-based cooking
    var cookingSteps: [CookingStep] = []

    // Simplified Mode
    var isSimplified: Bool = false

    // Fusion Mode
    var isFusion: Bool = false
    var additionalInspirationImagesData: [Data]?

    init(
        id: UUID = UUID(),
        dishName: String,
        recipeDescription: String,
        colorPalette: [String] = [],
        inspirationImageData: Data,
        generatedDishImageData: Data? = nil,
        generatedDishImageURL: String,
        translationMatrix: [TranslationItem],
        components: [RecipeComponent],
        cookingInstructions: [String] = [],
        platingSteps: [String],
        sommelierPairing: SommelierPairing,
        sceneAnalysis: SceneAnalysis? = nil,
        claudeRawResponse: String,
        chefPersonality: String? = nil,
        baseServings: Int = 2,
        estimatedCalories: Int? = nil,
        nutrition: NutritionInfo? = nil,
        prepTime: String? = nil,
        cookTime: String? = nil,
        difficulty: String? = nil,
        chefCommentary: String? = nil,
        cookingSteps: [CookingStep] = [],
        isSimplified: Bool = false,
        isFusion: Bool = false,
        additionalInspirationImagesData: [Data]? = nil
    ) {
        self.id = id
        self.dishName = dishName
        self.recipeDescription = recipeDescription
        self.colorPalette = colorPalette
        self.inspirationImageData = inspirationImageData
        self.generatedDishImageData = generatedDishImageData
        self.generatedDishImageURL = generatedDishImageURL
        self.translationMatrix = translationMatrix
        self.components = components
        self.cookingInstructions = cookingInstructions
        self.platingSteps = platingSteps
        self.sommelierPairing = sommelierPairing
        self.sceneAnalysis = sceneAnalysis
        self.createdAt = Date()
        self.updatedAt = Date()
        self.claudeRawResponse = claudeRawResponse
        self.chefPersonality = chefPersonality
        self.baseServings = max(1, baseServings)
        self.estimatedCalories = estimatedCalories
        self.nutrition = nutrition
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.difficulty = difficulty
        self.chefCommentary = chefCommentary
        self.cookingSteps = cookingSteps
        self.isSimplified = isSimplified
        self.isFusion = isFusion
        self.additionalInspirationImagesData = additionalInspirationImagesData
    }

    var effectiveCookingSteps: [CookingStep] {
        if !cookingSteps.isEmpty {
            return cookingSteps
        }
        return cookingInstructions.map { CookingStep(instruction: $0, ingredientsUsed: []) }
    }

    var allInspirationImages: [UIImage] {
        var images: [UIImage] = []
        if let img = UIImage(data: inspirationImageData) { images.append(img) }
        if let additional = additionalInspirationImagesData {
            images += additional.compactMap { UIImage(data: $0) }
        }
        return images
    }
}

struct TranslationItem: Codable, Hashable {
    var visual: String
    var culinary: String
}

struct IngredientSubstitution: Codable, Hashable {
    var original: String
    var substitutes: [String]
}

struct RecipeComponent: Codable, Hashable {
    var name: String
    var ingredients: [String]
    var method: String
    var substitutions: [IngredientSubstitution]?
}

struct CookingStep: Codable, Hashable {
    var instruction: String
    var ingredientsUsed: [String]
    var tip: String?
    var littleChef: String?

    enum CodingKeys: String, CodingKey {
        case instruction
        case ingredientsUsed = "ingredients_used"
        case tip
        case littleChef = "little_chef"
    }
}

struct NutritionInfo: Codable, Hashable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var fiber: Int
    var sugar: Int

    init(calories: Int, protein: Int, carbs: Int, fat: Int, fiber: Int, sugar: Int) {
        self.calories = max(0, calories)
        self.protein = max(0, protein)
        self.carbs = max(0, carbs)
        self.fat = max(0, fat)
        self.fiber = max(0, fiber)
        self.sugar = max(0, sugar)
    }
}

struct SommelierPairing: Codable, Hashable {
    var wine: String
    var cocktail: String
    var nonalcoholic: String
}

struct SceneAnalysis: Codable, Hashable {
    var detectedItems: [String]
    var detectedText: [String]
    var setting: String
    var approach: String  // "ingredient-driven", "visual-translation", "hybrid"

    private enum CodingKeys: String, CodingKey {
        case detectedItems, detectedText, setting, approach
        // Snake-case variants returned by the LLM API
        case detected_items, detected_text
    }

    init(detectedItems: [String], detectedText: [String], setting: String, approach: String) {
        self.detectedItems = detectedItems
        self.detectedText = detectedText
        self.setting = setting
        self.approach = approach
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? container.decode([String].self, forKey: .detectedItems) {
            self.detectedItems = items
        } else {
            self.detectedItems = try container.decode([String].self, forKey: .detected_items)
        }
        if let text = try? container.decode([String].self, forKey: .detectedText) {
            self.detectedText = text
        } else {
            self.detectedText = try container.decode([String].self, forKey: .detected_text)
        }
        self.setting = try container.decode(String.self, forKey: .setting)
        self.approach = try container.decode(String.self, forKey: .approach)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(detectedItems, forKey: .detectedItems)
        try container.encode(detectedText, forKey: .detectedText)
        try container.encode(setting, forKey: .setting)
        try container.encode(approach, forKey: .approach)
    }
}
