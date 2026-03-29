import Foundation
import UIKit
import SwiftData
import Supabase
import ActivityKit
import WidgetKit
import os

private let logger = makeLogger(category: "Pipeline")

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

// MARK: - Edge Function Response Types

struct ScreenImageResponse: Codable {
    let safe: Bool
    let reason: String
}

struct AnalyzeImageResponse: Codable {
    let recipe: ClaudeRecipeResponse
    let rawJSON: String
}

struct GenerateImageResponse: Codable {
    let imageData: String
    let mimeType: String
}

// MARK: - Edge Function Request Types

struct ScreenImageRequest: Encodable {
    let images: [String]
}

struct AnalyzeImageRequest: Encodable {
    let images: [String]
    let provider: String
    let chef: String
    let customChefConfig: CustomChefConfigPayload?
    let dietaryPreferences: [String]?
    let hardExcluding: [String]
    let softAvoiding: [String]
    let budgetLimit: Double?
    let courseType: String?
}

struct CustomChefConfigPayload: Encodable {
    let skillLevel: String
    let cuisines: [String]
    let personality: String
}

struct GenerateImageRequest: Encodable {
    let prompt: String
    let provider: String
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
    var isFusion: Bool = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    var imageGenModelName: String { imageGenModel.displayName }

    private let imageGenModel: ImageGenerationModel

    init(imageGenModel: ImageGenerationModel? = nil) {
        let model = imageGenModel ?? {
            let raw = UserDefaults.standard.string(forKey: "debug_imageGenModel") ?? ImageGenerationModel.imagen4.rawValue
            return ImageGenerationModel(rawValue: raw) ?? .imagen4
        }()
        self.imageGenModel = model
    }

    func process(image: UIImage, modelContext: ModelContext, hardExcluding: [String] = [], softAvoiding: [String] = [], budgetLimit: Double? = nil, courseType: String? = nil) async {
        logger.info("Pipeline started — hardExclude: \(hardExcluding), softAvoid: \(softAvoiding.count) items, budget: \(budgetLimit?.description ?? "none"), courseType: \(courseType ?? "none")")
        startTime = Date()
        await LiveActivityManager.shared.startGeneration()

        guard let inspirationData = image.jpegData(compressionQuality: 0.9) else {
            logger.error("Failed to convert image to JPEG data")
            state = .failed("Could not process the captured image.")
            return
        }
        logger.info("Inspiration image: \(inspirationData.count) bytes")

        let base64Image = inspirationData.base64EncodedString()

        do {
            // Step 0: Content screening via edge function
            state = .screeningImage
            processingStatus = "Checking image..."
            await LiveActivityManager.shared.updatePhase("Screening", progress: 0.1, status: "Checking image...")
            logger.info("Screening image for content safety...")

            let screening: ScreenImageResponse = try await withExponentialBackoff {
                try await self.supabase.functions.invoke("screen-image", options: .init(body: ScreenImageRequest(images: [base64Image])))
            }
            try Task.checkCancellation()
            if !screening.safe {
                logger.info("Image rejected: \(screening.reason)")
                state = .rejected(screening.reason)
                return
            }
            logger.info("Image passed screening: \(screening.reason)")

            // Step 1: Recipe analysis via edge function
            state = .analyzingImage
            processingStatus = "Extracting palette..."
            await LiveActivityManager.shared.updatePhase("Analyzing", progress: 0.35, status: "Extracting palette...")
            let chef = ChefPersonality.current
            logger.info("Calling analyze-image with chef: \(chef.displayName)...")

            let analysisRequest = buildAnalysisRequest(
                base64Images: [base64Image],
                chef: chef,
                hardExcluding: hardExcluding,
                softAvoiding: softAvoiding,
                budgetLimit: budgetLimit,
                courseType: courseType
            )

            let analysisResponse: AnalyzeImageResponse = try await withExponentialBackoff {
                try await self.supabase.functions.invoke("analyze-image", options: .init(body: analysisRequest))
            }
            let recipeResponse = analysisResponse.recipe
            let rawJSON = analysisResponse.rawJSON
            try Task.checkCancellation()
            logger.info("Analysis response received — dish: \(recipeResponse.dishName)")
            logger.debug("Image gen prompt: \(recipeResponse.imageGenerationPrompt.prefix(100))...")

            extractedColors = recipeResponse.colorPalette ?? []
            partialDishName = recipeResponse.dishName
            partialIngredients = recipeResponse.components.flatMap { $0.ingredients }
            processingStatus = "Translating emotion..."

            // Step 2: Image generation via edge function (non-fatal)
            try Task.checkCancellation()
            state = .generatingImage
            processingStatus = "Plating concept..."
            await LiveActivityManager.shared.updatePhase("Generating", progress: 0.65, status: "Plating concept...")
            logger.info("Generating image with \(self.imageGenModel.displayName)...")

            var generatedImageData: Data? = nil
            var imageURL: String = ""
            do {
                let genResponse: GenerateImageResponse = try await withExponentialBackoff {
                    try await self.supabase.functions.invoke("generate-image", options: .init(body: GenerateImageRequest(
                        prompt: recipeResponse.imageGenerationPrompt,
                        provider: self.imageGenModel.edgeFunctionKey
                    )))
                }
                generatedImageData = Data(base64Encoded: genResponse.imageData)
                imageURL = genResponse.mimeType
                logger.info("\(self.imageGenModel.displayName) response — image: \(generatedImageData?.count ?? 0) bytes")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("Image generation failed, continuing without image: \(error)")
            }

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
                nutrition: recipeResponse.nutrition,
                prepTime: recipeResponse.prepTime,
                cookTime: recipeResponse.cookTime,
                cookingSteps: recipeResponse.cookingSteps ?? []
            )

            completedRecipe = recipe
            state = .complete
            UsageTracker.shared.incrementUsage()
            await CommunityImpactService.shared.recordGeneration()
            if recipe.generatedDishImageData != nil {
                updateWidgetData(recipe: recipe)
            }
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

    // MARK: - Fusion Mode

    func processFusion(images: [UIImage], modelContext: ModelContext, hardExcluding: [String] = [], softAvoiding: [String] = [], budgetLimit: Double? = nil, courseType: String? = nil) async {
        guard !images.isEmpty else {
            logger.error("Fusion pipeline called with no images")
            state = .failed("No images provided for fusion.")
            return
        }
        logger.info("Fusion pipeline started — \(images.count) images, hardExclude: \(hardExcluding), softAvoid: \(softAvoiding.count) items, budget: \(budgetLimit?.description ?? "none")")
        isFusion = true
        startTime = Date()
        await LiveActivityManager.shared.startGeneration()

        // Convert images to JPEG data and base64 one at a time to reduce peak memory
        var allImageData: [Data] = []
        var base64Images: [String] = []
        for (index, image) in images.enumerated() {
            guard let data = image.jpegDataForUpload() else {
                logger.error("Failed to convert fusion image \(index) to JPEG data")
                state = .failed("Could not process one of the captured images.")
                return
            }
            allImageData.append(data)
            base64Images.append(data.base64EncodedString())
        }
        logger.info("All \(allImageData.count) fusion images converted to JPEG")

        do {
            // Step 0: Content screening via edge function
            state = .screeningImage
            processingStatus = "Checking images..."
            await LiveActivityManager.shared.updatePhase("Screening", progress: 0.1, status: "Checking images...")
            logger.info("Screening \(images.count) images for content safety...")

            let screening: ScreenImageResponse = try await withExponentialBackoff {
                try await self.supabase.functions.invoke("screen-image", options: .init(body: ScreenImageRequest(images: base64Images)))
            }
            try Task.checkCancellation()
            if !screening.safe {
                logger.info("Fusion image rejected: \(screening.reason)")
                state = .rejected(screening.reason)
                return
            }
            logger.info("All fusion images passed screening")

            // Step 1: Recipe analysis via edge function
            state = .analyzingImage
            processingStatus = "Blending visual worlds..."
            await LiveActivityManager.shared.updatePhase("Analyzing", progress: 0.35, status: "Fusing visual DNA...")
            let chef = ChefPersonality.current
            logger.info("Calling analyze-image with \(images.count) images, chef: \(chef.displayName)...")

            let analysisRequest = buildAnalysisRequest(
                base64Images: base64Images,
                chef: chef,
                hardExcluding: hardExcluding,
                softAvoiding: softAvoiding,
                budgetLimit: budgetLimit,
                courseType: courseType
            )

            let analysisResponse: AnalyzeImageResponse = try await withExponentialBackoff {
                try await self.supabase.functions.invoke("analyze-image", options: .init(body: analysisRequest))
            }
            let recipeResponse = analysisResponse.recipe
            let rawJSON = analysisResponse.rawJSON
            try Task.checkCancellation()
            logger.info("Fusion analysis response received — dish: \(recipeResponse.dishName)")

            extractedColors = recipeResponse.colorPalette ?? []
            partialDishName = recipeResponse.dishName
            partialIngredients = recipeResponse.components.flatMap { $0.ingredients }
            processingStatus = "Translating fusion..."

            // Step 2: Image generation via edge function (non-fatal)
            try Task.checkCancellation()
            state = .generatingImage
            processingStatus = "Plating concept..."
            await LiveActivityManager.shared.updatePhase("Generating", progress: 0.65, status: "Plating concept...")
            logger.info("Generating image with \(self.imageGenModel.displayName)...")

            var generatedImageData: Data? = nil
            var imageURL: String = ""
            do {
                let genResponse: GenerateImageResponse = try await withExponentialBackoff {
                    try await self.supabase.functions.invoke("generate-image", options: .init(body: GenerateImageRequest(
                        prompt: recipeResponse.imageGenerationPrompt,
                        provider: self.imageGenModel.edgeFunctionKey
                    )))
                }
                generatedImageData = Data(base64Encoded: genResponse.imageData)
                imageURL = genResponse.mimeType
                logger.info("\(self.imageGenModel.displayName) response — image: \(generatedImageData?.count ?? 0) bytes")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("Image generation failed, continuing without image: \(error)")
            }

            // Step 3: Create Recipe with fusion data
            guard let primaryImageData = allImageData.first else {
                logger.error("No image data available for fusion recipe")
                state = .failed("Could not process the captured images.")
                return
            }
            let additionalData = allImageData.count > 1 ? Array(allImageData.dropFirst()) : nil
            logger.info("Fusion recipe — additionalData count: \(additionalData?.count ?? 0), sizes: \(additionalData?.map { $0.count } ?? [])")

            let recipe = Recipe(
                dishName: recipeResponse.dishName,
                recipeDescription: recipeResponse.description,
                colorPalette: recipeResponse.colorPalette ?? [],
                inspirationImageData: primaryImageData,
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
                nutrition: recipeResponse.nutrition,
                prepTime: recipeResponse.prepTime,
                cookTime: recipeResponse.cookTime,
                cookingSteps: recipeResponse.cookingSteps ?? [],
                isFusion: true,
                additionalInspirationImagesData: additionalData
            )

            completedRecipe = recipe
            state = .complete
            UsageTracker.shared.incrementUsage()
            await CommunityImpactService.shared.recordGeneration()
            if recipe.generatedDishImageData != nil {
                updateWidgetData(recipe: recipe)
            }
            await LiveActivityManager.shared.endGeneration(dishName: recipe.dishName)
            logger.info("Fusion pipeline complete — recipe ready")

        } catch is CancellationError {
            logger.info("Fusion pipeline cancelled")
            await LiveActivityManager.shared.cancelGeneration()
        } catch {
            logger.error("Fusion pipeline failed: \(error)")
            state = .failed(error.localizedDescription)
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        }
    }

    // MARK: - Analysis Request Builder

    private func buildAnalysisRequest(
        base64Images: [String],
        chef: ChefPersonality,
        hardExcluding: [String],
        softAvoiding: [String],
        budgetLimit: Double?,
        courseType: String?
    ) -> AnalyzeImageRequest {
        let dietaryPrefs = DietaryPreference.current()

        var customConfig: CustomChefConfigPayload?
        if chef == .custom, let config = CustomChefConfig.load() {
            customConfig = CustomChefConfigPayload(
                skillLevel: config.skillLevel.rawValue,
                cuisines: config.cuisines.map(\.rawValue),
                personality: config.personality.rawValue
            )
        }

        return AnalyzeImageRequest(
            images: base64Images,
            provider: "gemini",
            chef: chef.rawValue,
            customChefConfig: customConfig,
            dietaryPreferences: dietaryPrefs.isEmpty ? nil : dietaryPrefs.map(\.rawValue),
            hardExcluding: hardExcluding,
            softAvoiding: softAvoiding,
            budgetLimit: budgetLimit,
            courseType: courseType
        )
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

// MARK: - ImageGenerationModel Edge Function Key

extension ImageGenerationModel {
    var edgeFunctionKey: String {
        switch self {
        case .imagen4: return "imagen4"
        case .imagen4Fast: return "imagen4fast"
        case .fluxPro: return "fluxpro"
        case .fluxSchnell: return "fluxschnell"
        }
    }
}
