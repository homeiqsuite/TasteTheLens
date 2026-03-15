import SwiftData
import Foundation

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
        claudeRawResponse: String
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
        self.claudeRawResponse = claudeRawResponse
    }
}

struct TranslationItem: Codable, Hashable {
    var visual: String
    var culinary: String
}

struct RecipeComponent: Codable, Hashable {
    var name: String
    var ingredients: [String]
    var method: String
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

    enum CodingKeys: String, CodingKey {
        case detectedItems = "detected_items"
        case detectedText = "detected_text"
        case setting
        case approach
    }
}
