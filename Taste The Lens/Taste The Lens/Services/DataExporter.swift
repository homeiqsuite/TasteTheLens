import Foundation

struct DataExporter {

    struct UserExportInfo: Codable {
        let displayName: String
        let email: String
        let memberSince: Date
        let subscriptionTier: String
    }

    struct RecipeExportDTO: Codable {
        let id: String
        let dishName: String
        let description: String
        let colorPalette: [String]
        let translationMatrix: [TranslationItem]
        let components: [RecipeComponent]
        let cookingInstructions: [String]
        let cookingSteps: [CookingStep]
        let platingSteps: [String]
        let sommelierPairing: SommelierPairing
        let sceneAnalysis: SceneAnalysis?
        let chefPersonality: String?
        let baseServings: Int
        let estimatedCalories: Int?
        let nutrition: NutritionInfo?
        let generatedDishImageURL: String
        let createdAt: Date
    }

    private struct ExportPackage: Codable {
        let exportDate: Date
        let user: UserExportInfo
        let recipeCount: Int
        let recipes: [RecipeExportDTO]
    }

    static func exportJSON(recipes: [Recipe], user: UserExportInfo) -> Data {
        let dtos = recipes.map { recipe in
            RecipeExportDTO(
                id: recipe.id.uuidString,
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
                chefPersonality: recipe.chefPersonality,
                baseServings: recipe.baseServings,
                estimatedCalories: recipe.estimatedCalories,
                nutrition: recipe.nutrition,
                generatedDishImageURL: recipe.generatedDishImageURL,
                createdAt: recipe.createdAt
            )
        }

        let package = ExportPackage(
            exportDate: Date(),
            user: user,
            recipeCount: dtos.count,
            recipes: dtos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return (try? encoder.encode(package)) ?? Data()
    }

    static func exportFileURL(data: Data) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        // The export contains the user's email + full recipe collection (PII), so
        // write it encrypted-at-rest and excluded from backup rather than as a
        // plain file in the temp directory.
        return TempFileManager.write(data, fileName: "TasteTheLens_Export_\(dateString).json")
    }
}
