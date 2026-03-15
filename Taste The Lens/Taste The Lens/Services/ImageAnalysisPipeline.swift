import Foundation
import UIKit
import SwiftData
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
final class ImageAnalysisPipeline {
    var state: PipelineState = .idle
    var processingStatus: String = ""
    var completedRecipe: Recipe?
    var extractedColors: [String] = []

    private let geminiClient = GeminiAPIClient()
    private let falClient = FalAPIClient()

    func process(image: UIImage, modelContext: ModelContext) async {
        logger.info("Pipeline started")

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
            logger.info("Screening image for content safety...")

            let screening = try await geminiClient.screenImage(image)
            if !screening.safe {
                logger.info("Image rejected: \(screening.reason)")
                state = .rejected(screening.reason)
                return
            }
            logger.info("Image passed screening: \(screening.reason)")

            // Step 1: Gemini analysis
            state = .analyzingImage
            processingStatus = "Extracting palette..."
            logger.info("Calling Gemini API...")

            let (recipeResponse, rawJSON) = try await geminiClient.analyzeImage(image)
            logger.info("Gemini response received — dish: \(recipeResponse.dishName)")
            logger.debug("Image gen prompt: \(recipeResponse.imageGenerationPrompt.prefix(100))...")

            extractedColors = recipeResponse.colorPalette ?? []
            processingStatus = "Translating emotion..."

            // Step 2: fal.ai image generation
            state = .generatingImage
            processingStatus = "Plating concept..."
            logger.info("Calling fal.ai API...")

            let enhancedPrompt = recipeResponse.imageGenerationPrompt
                + " Professional editorial food photography, Michelin star presentation, warm inviting lighting, shallow depth of field, 85mm lens, appetizing and delicious."
            let (generatedImageData, imageURL) = try await falClient.generateImage(
                prompt: enhancedPrompt
            )
            logger.info("fal.ai response received — image: \(generatedImageData.count) bytes, URL: \(imageURL)")

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
                claudeRawResponse: rawJSON
            )

            completedRecipe = recipe
            state = .complete
            logger.info("Pipeline complete — recipe ready")

        } catch {
            logger.error("Pipeline failed: \(error)")
            state = .failed(error.localizedDescription)
        }
    }
}
