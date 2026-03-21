import Foundation
import UIKit
import SwiftData
import ActivityKit
import WidgetKit
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Pipeline")

enum PipelineState: Equatable {
    case idle
    case screeningImage
    case analyzingImage
    case generatingImage
    case complete
    case failed(String)
    case rejected(String)

    static func == (lhs: PipelineState, rhs: PipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.screeningImage, .screeningImage),
             (.analyzingImage, .analyzingImage),
             (.generatingImage, .generatingImage), (.complete, .complete):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.rejected(let a), .rejected(let b)):
            return a == b
        default:
            return false
        }
    }
}

@Observable
final class ImageAnalysisPipeline: Identifiable {
    let id = UUID()
    var state: PipelineState = .idle
    var processingStatus: String = ""
    var completedRecipe: Recipe?
    var extractedColors: [String] = []
    var partialDishName: String?
    var partialIngredients: [String] = []
    var startTime: Date?

    private let geminiClient = GeminiAPIClient()

    var imageGenModelName: String { imageGenModel.displayName }

    private let imageGenModel: ImageGenerationModel
    private let imageGenClient: ImageGenerationProviding

    init(imageGenModel: ImageGenerationModel? = nil) {
        let model = imageGenModel ?? {
            let raw = UserDefaults.standard.string(forKey: "debug_imageGenModel") ?? ImageGenerationModel.imagen4.rawValue
            return ImageGenerationModel(rawValue: raw) ?? .imagen4
        }()
        self.imageGenModel = model
        self.imageGenClient = ImageGenerationFactory.client(for: model)
    }

    func process(image: UIImage, modelContext: ModelContext, excluding: [String] = [], budgetLimit: Double? = nil, courseType: String? = nil) async {
        logger.info("Pipeline started — excluding: \(excluding), budget: \(budgetLimit?.description ?? "none"), courseType: \(courseType ?? "none")")
        startTime = Date()
        await LiveActivityManager.shared.startGeneration()

        guard let inspirationData = image.jpegData(compressionQuality: 0.9) else {
            logger.error("Failed to convert image to JPEG data")
            state = .failed("Could not process the captured image.")
            return
        }
        logger.info("Inspiration image: \(inspirationData.count) bytes")

        do {
            // Step 0: Content screening
            state = .screeningImage
            processingStatus = "Checking image..."
            await LiveActivityManager.shared.updatePhase("Screening", progress: 0.1, status: "Checking image...")
            logger.info("Screening image for content safety...")

            let screening = try await withExponentialBackoff {
                try await geminiClient.screenImage(image)
            }
            try Task.checkCancellation()
            if !screening.safe {
                logger.info("Image rejected: \(screening.reason)")
                state = .rejected(screening.reason)
                return
            }
            logger.info("Image passed screening: \(screening.reason)")

            // Step 1: Gemini analysis
            state = .analyzingImage
            processingStatus = "Extracting palette..."
            await LiveActivityManager.shared.updatePhase("Analyzing", progress: 0.35, status: "Extracting palette...")
            let chef = ChefPersonality.current
            logger.info("Calling Gemini API with chef: \(chef.displayName)...")

            var prompt = chef.systemPrompt
            if !excluding.isEmpty {
                let excludeList = excluding.joined(separator: ", ")
                prompt += "\n\nIMPORTANT: Generate a completely different dish. Do NOT repeat any of these previously generated dishes: \(excludeList). Create something entirely new and distinct."
            }
            if let budgetLimit {
                let formatted = budgetLimit.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "$%.0f", budgetLimit)
                    : String(format: "$%.2f", budgetLimit)
                prompt += "\n\nBUDGET CONSTRAINT: The total cost of ALL ingredients combined must be under \(formatted). Choose affordable, budget-friendly ingredients. Prioritize pantry staples, in-season produce, and cost-effective proteins (chicken thighs, eggs, beans, lentils, ground meat). Avoid expensive ingredients like seafood, specialty cheeses, or premium cuts. The dish should taste great without breaking the bank."
            }
            if let courseType {
                prompt += "\n\nCOURSE TYPE CONSTRAINT: Create this as a \(courseType). The dish format, portion size, presentation, and ingredient quantities should all match what you'd expect from a \(courseType). For example, appetizers should be small and shareable, desserts should be sweet, drinks should be beverages, etc."
            }

            let (recipeResponse, rawJSON) = try await withExponentialBackoff {
                try await geminiClient.analyzeImage(image, systemPrompt: prompt)
            }
            try Task.checkCancellation()
            logger.info("Gemini response received — dish: \(recipeResponse.dishName)")
            logger.debug("Image gen prompt: \(recipeResponse.imageGenerationPrompt.prefix(100))...")

            extractedColors = recipeResponse.colorPalette ?? []
            partialDishName = recipeResponse.dishName
            partialIngredients = recipeResponse.components.flatMap { $0.ingredients }
            processingStatus = "Translating emotion..."

            // Step 2: Image generation
            try Task.checkCancellation()
            state = .generatingImage
            processingStatus = "Plating concept..."
            await LiveActivityManager.shared.updatePhase("Generating", progress: 0.65, status: "Plating concept...")
            logger.info("Generating image with \(self.imageGenModel.displayName)...")

            let enhancedPrompt = recipeResponse.imageGenerationPrompt
                + " Professional editorial food photography, Michelin star presentation, warm inviting lighting, shallow depth of field, 85mm lens, appetizing and delicious."
            let (generatedImageData, imageURL) = try await withExponentialBackoff {
                try await imageGenClient.generateImage(prompt: enhancedPrompt)
            }
            logger.info("\(self.imageGenModel.displayName) response — image: \(generatedImageData.count) bytes, URL: \(imageURL)")

            // Step 3: Create Recipe
            let recipe = Recipe(
                dishName: recipeResponse.dishName,
                recipeDescription: recipeResponse.description,
                colorPalette: recipeResponse.colorPalette ?? [],
                inspirationImageData: inspirationData,
                generatedDishImageData: generatedImageData,
                generatedDishImageURL: imageURL,
                translationMatrix: recipeResponse.translationMatrix,
                components: recipeResponse.components,
                cookingInstructions: recipeResponse.cookingInstructions ?? [],
                platingSteps: recipeResponse.platingSteps,
                sommelierPairing: recipeResponse.sommelierPairing,
                sceneAnalysis: recipeResponse.sceneAnalysis,
                claudeRawResponse: rawJSON,
                chefPersonality: chef.rawValue,
                baseServings: recipeResponse.baseServings ?? 2,
                estimatedCalories: recipeResponse.estimatedCalories,
                nutrition: recipeResponse.nutrition
            )

            completedRecipe = recipe
            state = .complete
            UsageTracker.shared.incrementUsage()
            await CommunityImpactService.shared.recordGeneration()
            updateWidgetData(recipe: recipe)
            await LiveActivityManager.shared.endGeneration(dishName: recipe.dishName)
            logger.info("Pipeline complete — recipe ready")

        } catch is CancellationError {
            logger.info("Pipeline cancelled")
            await LiveActivityManager.shared.cancelGeneration()
        } catch {
            logger.error("Pipeline failed: \(error)")
            state = .failed(error.localizedDescription)
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        }
    }

    // MARK: - Widget Data

    private func updateWidgetData(recipe: Recipe) {
        guard let defaults = UserDefaults(suiteName: "group.com.eightgates.TasteTheLens") else { return }
        defaults.set(recipe.dishName, forKey: "lastRecipeDishName")
        defaults.set(recipe.createdAt.timeIntervalSince1970, forKey: "lastRecipeCreatedAt")
        // Store a small thumbnail for the widget
        if let imageData = recipe.generatedDishImageData,
           let image = UIImage(data: imageData),
           let thumbnail = image.resizedForAPIUpload(maxDimension: 200).jpegData(compressionQuality: 0.6) {
            defaults.set(thumbnail, forKey: "lastRecipeThumbnail")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
