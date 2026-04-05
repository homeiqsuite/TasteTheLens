import Foundation
import UIKit
import SwiftData
import Supabase
import ActivityKit
import WidgetKit
import Network
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
    case insufficientCredits

    static func == (lhs: PipelineState, rhs: PipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.screeningImage, .screeningImage),
             (.analyzingImage, .analyzingImage),
             (.generatingImage, .generatingImage), (.complete, .complete),
             (.insufficientCredits, .insufficientCredits):
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

// MARK: - Edge Function Error

struct EdgeFunctionError: LocalizedError {
    let statusCode: Int
    let body: String
    var errorDescription: String? {
        if statusCode == 402 { return "You've run out of credits. Purchase more to continue creating recipes." }
        if statusCode == 422 { return rejectionReason ?? "Image not suitable for recipe generation." }
        if statusCode == 429 { return "Too many requests. Please wait a moment and try again." }
        if statusCode == 503 { return "Content screening unavailable. Please try again." }
        return "Server error (\(statusCode)). Please try again."
    }
    var isInsufficientCredits: Bool { statusCode == 402 }
    var isContentRejected: Bool { statusCode == 422 }
    var isRateLimit: Bool { statusCode == 429 }
    var isRetryable: Bool { statusCode >= 500 && statusCode != 503 }

    /// Parses the rejection reason from a 422 response body.
    var rejectionReason: String? {
        guard isContentRejected,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reason = json["reason"] as? String else { return nil }
        return reason
    }
}

// MARK: - Edge Function Response Types

struct CreditBalance: Codable {
    let purchased_credits: Int
    let subscription_credits: Int
    let rollover_credits: Int
    let free_usage_count: Int
    let pool: String?
}

struct AnalysisUsage: Codable {
    let provider: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let costUsd: Double
}

struct AnalyzeImageResponse: Codable {
    let recipe: ClaudeRecipeResponse
    let rawJSON: String
    let credits: CreditBalance?
    let usage: AnalysisUsage?
}

struct GenerateImageResponse: Codable {
    let imageData: String
    let mimeType: String
    let costUsd: Double?
}

// MARK: - Edge Function Request Types

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
    let cultureName: String?
    let simplifyMode: Bool?
    let skillLevel: String?
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
    /// Set when image generation fails but the recipe was still created successfully
    var imageGenerationFailed: Bool = false

    private var creditPool: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    /// Network connectivity check using the shared NetworkMonitor.
    private func checkConnectivity() async -> Bool {
        await MainActor.run { NetworkMonitor.shared.isConnected }
    }

    /// Returns the user's access token if authenticated, or nil for guests.
    private func userAccessToken() async -> String? {
        guard AuthManager.shared.isAuthenticated,
              let session = try? await supabase.auth.session else { return nil }
        return session.accessToken
    }

    /// Calls a Supabase edge function directly via URLSession, bypassing SDK auth handling.
    /// Always authenticates with the anon key (so the gateway never rejects expired JWTs).
    /// The user's token is passed in a custom x-user-token header for the function to read.
    private func invokeEdgeFunction<Request: Encodable, Response: Decodable>(
        _ functionName: String,
        body: Request
    ) async throws -> Response {
        let baseURL = AppConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/functions/v1/\(functionName)") else {
            throw URLError(.badURL)
        }

        let encodedBody = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        // Always use anon key for Authorization so the Supabase gateway never returns 401.
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        // Pass user JWT in a custom header — the edge function reads it for optional auth.
        if let userToken = await userAccessToken() {
            request.setValue(userToken, forHTTPHeaderField: "x-user-token")
        }
        request.httpBody = encodedBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("Edge function \(functionName) returned \(httpResponse.statusCode): \(body)")
            throw EdgeFunctionError(statusCode: httpResponse.statusCode, body: body)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    var imageGenModelName: String { imageGenModel.displayName }

    private let imageGenModel: ImageGenerationModel

    init(imageGenModel: ImageGenerationModel? = nil) {
        let model = imageGenModel ?? {
            let raw = UserDefaults.standard.string(forKey: "debug_imageGenModel") ?? ImageGenerationModel.imagen4.rawValue
            return ImageGenerationModel(rawValue: raw) ?? .imagen4
        }()
        self.imageGenModel = model
    }

    func process(image: UIImage, modelContext: ModelContext, hardExcluding: [String] = [], softAvoiding: [String] = [], budgetLimit: Double? = nil, courseType: String? = nil, cultureName: String? = nil, simplifyMode: Bool = false) async {
        guard await checkConnectivity() else {
            logger.error("No network connectivity")
            state = .failed("No internet connection. Please check your network and try again.")
            return
        }
        logger.info("Pipeline started — hardExclude: \(hardExcluding), softAvoid: \(softAvoiding.count) items, budget: \(budgetLimit?.description ?? "none"), courseType: \(courseType ?? "none"), culture: \(cultureName ?? "none")")
        startTime = Date()
        await LiveActivityManager.shared.startGeneration()

        let inspirationData: Data
        let base64Image: String

        // Resize for API upload (max 1024px, 0.8 quality) to stay within edge function body limits
        if let uploadData = image.jpegDataForUpload() {
            inspirationData = uploadData
        } else if let fallback = image.jpegData(compressionQuality: 0.8) {
            inspirationData = fallback
        } else {
            logger.error("Failed to convert image to JPEG data")
            state = .failed("Could not process the captured image.")
            return
        }
        logger.info("Inspiration image: \(inspirationData.count) bytes")
        base64Image = inspirationData.base64EncodedString()

        do {
            // Step 1: Recipe analysis (screening is now performed server-side in parallel with credit deduction)
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
                courseType: courseType,
                cultureName: cultureName,
                simplifyMode: simplifyMode
            )

            let analysisStart = Date()
            let analysisResponse: AnalyzeImageResponse = try await withTimeout(seconds: 90) {
                try await withExponentialBackoff {
                    try await self.invokeEdgeFunction("analyze-image", body: analysisRequest)
                }
            }
            logger.info("⏱ analyze-image: \(String(format: "%.1f", Date().timeIntervalSince(analysisStart)))s")
            // Update local credit cache from server response
            if let credits = analysisResponse.credits {
                await MainActor.run { UsageTracker.shared.updateFromServer(credits) }
                creditPool = credits.pool
            } else if AuthManager.shared.isAuthenticated {
                // No credits in response — server may not have resolved the user token.
                // Sync usage from server so the UI reflects the actual state.
                Task { await UsageTracker.shared.syncUsageFromServer() }
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
            var imageCostUsd: Double? = nil

            // Re-check connectivity before starting image gen — avoids a 120s timeout if network dropped
            if await checkConnectivity() {
                do {
                    let genStart = Date()
                    let genResponse: GenerateImageResponse = try await withTimeout(seconds: 120) {
                        try await withExponentialBackoff {
                            try await self.invokeEdgeFunction("generate-image", body: GenerateImageRequest(
                                prompt: recipeResponse.imageGenerationPrompt,
                                provider: self.imageGenModel.edgeFunctionKey
                            ))
                        }
                    }
                    generatedImageData = Data(base64Encoded: genResponse.imageData)
                    imageURL = genResponse.mimeType
                    imageCostUsd = genResponse.costUsd
                    logger.info("⏱ generate-image (\(self.imageGenModel.displayName)): \(String(format: "%.1f", Date().timeIntervalSince(genStart)))s — \(generatedImageData?.count ?? 0) bytes")
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    logger.error("Image generation failed, continuing without image: \(error)")
                    imageGenerationFailed = true
                }
            } else {
                logger.warning("Skipping image generation — network lost after analysis")
                imageGenerationFailed = true
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
                difficulty: recipeResponse.difficulty,
                chefCommentary: recipeResponse.chefCommentary,
                cookingSteps: recipeResponse.cookingSteps ?? [],
                isSimplified: simplifyMode
            )

            completedRecipe = recipe
            creditPool = nil
            state = .complete
            // Guest users: track usage locally (server doesn't enforce for unauthenticated users)
            UsageTracker.shared.incrementGuestUsage()
            await CommunityImpactService.shared.recordGeneration()
            if recipe.generatedDishImageData != nil {
                updateWidgetData(recipe: recipe)
            }
            await LiveActivityManager.shared.endGeneration(dishName: recipe.dishName)

            // Track generation cost
            AnalyticsClient.shared.trackRecipeGeneration(
                analysisProvider: analysisResponse.usage?.provider,
                analysisModel: analysisResponse.usage?.model,
                analysisInputTokens: analysisResponse.usage?.inputTokens,
                analysisOutputTokens: analysisResponse.usage?.outputTokens,
                analysisCostUsd: analysisResponse.usage?.costUsd,
                imageProvider: imageGenModel.edgeFunctionKey,
                imageCostUsd: imageCostUsd,
                captureMode: "single",
                imageCount: 1,
                chefPersonality: chef.rawValue
            )

            if let start = startTime {
                logger.info("⏱ Pipeline total: \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
            }
            logger.info("Pipeline complete — recipe ready")

        } catch is CancellationError {
            logger.info("Pipeline cancelled")
            await refundCreditIfNeeded()
            await LiveActivityManager.shared.cancelGeneration()
        } catch let error as EdgeFunctionError where error.isContentRejected {
            let reason = error.rejectionReason ?? "Image not suitable for recipe generation."
            logger.info("Image rejected by server: \(reason)")
            state = .rejected(reason)
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        } catch let error as EdgeFunctionError where error.isInsufficientCredits {
            logger.warning("Insufficient credits — prompting purchase")
            state = .insufficientCredits
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        } catch {
            logger.error("Pipeline failed: \(error)")
            logger.error("Pipeline error type: \(type(of: error)), description: \(String(describing: error))")
            await refundCreditIfNeeded()
            state = .failed(error.localizedDescription)
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        }
    }

    // MARK: - Fusion Mode

    func processFusion(images: [UIImage], modelContext: ModelContext, hardExcluding: [String] = [], softAvoiding: [String] = [], budgetLimit: Double? = nil, courseType: String? = nil, cultureName: String? = nil, simplifyMode: Bool = false) async {
        guard !images.isEmpty else {
            logger.error("Fusion pipeline called with no images")
            state = .failed("No images provided for fusion.")
            return
        }
        guard await checkConnectivity() else {
            logger.error("No network connectivity")
            state = .failed("No internet connection. Please check your network and try again.")
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
            // Step 1: Recipe analysis (screening is now performed server-side in parallel with credit deduction)
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
                courseType: courseType,
                cultureName: cultureName,
                simplifyMode: simplifyMode
            )

            let analysisStart = Date()
            let analysisResponse: AnalyzeImageResponse = try await withTimeout(seconds: 90) {
                try await withExponentialBackoff {
                    try await self.invokeEdgeFunction("analyze-image", body: analysisRequest)
                }
            }
            logger.info("⏱ analyze-image (fusion): \(String(format: "%.1f", Date().timeIntervalSince(analysisStart)))s")
            // Update local credit cache from server response
            if let credits = analysisResponse.credits {
                await MainActor.run { UsageTracker.shared.updateFromServer(credits) }
                creditPool = credits.pool
            } else if AuthManager.shared.isAuthenticated {
                Task { await UsageTracker.shared.syncUsageFromServer() }
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
            var imageCostUsd: Double? = nil

            // Re-check connectivity before starting image gen — avoids a 120s timeout if network dropped
            if await checkConnectivity() {
                do {
                    let genStart = Date()
                    let genResponse: GenerateImageResponse = try await withTimeout(seconds: 120) {
                        try await withExponentialBackoff {
                            try await self.invokeEdgeFunction("generate-image", body: GenerateImageRequest(
                                prompt: recipeResponse.imageGenerationPrompt,
                                provider: self.imageGenModel.edgeFunctionKey
                            ))
                        }
                    }
                    generatedImageData = Data(base64Encoded: genResponse.imageData)
                    imageURL = genResponse.mimeType
                    imageCostUsd = genResponse.costUsd
                    logger.info("⏱ generate-image (fusion, \(self.imageGenModel.displayName)): \(String(format: "%.1f", Date().timeIntervalSince(genStart)))s — \(generatedImageData?.count ?? 0) bytes")
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    logger.error("Image generation failed, continuing without image: \(error)")
                    imageGenerationFailed = true
                }
            } else {
                logger.warning("Skipping fusion image generation — network lost after analysis")
                imageGenerationFailed = true
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
                difficulty: recipeResponse.difficulty,
                chefCommentary: recipeResponse.chefCommentary,
                cookingSteps: recipeResponse.cookingSteps ?? [],
                isFusion: true,
                additionalInspirationImagesData: additionalData
            )

            completedRecipe = recipe
            creditPool = nil
            state = .complete
            // Guest users: track usage locally (server doesn't enforce for unauthenticated users)
            UsageTracker.shared.incrementGuestUsage()
            await CommunityImpactService.shared.recordGeneration()
            if recipe.generatedDishImageData != nil {
                updateWidgetData(recipe: recipe)
            }
            await LiveActivityManager.shared.endGeneration(dishName: recipe.dishName)

            // Track generation cost
            AnalyticsClient.shared.trackRecipeGeneration(
                analysisProvider: analysisResponse.usage?.provider,
                analysisModel: analysisResponse.usage?.model,
                analysisInputTokens: analysisResponse.usage?.inputTokens,
                analysisOutputTokens: analysisResponse.usage?.outputTokens,
                analysisCostUsd: analysisResponse.usage?.costUsd,
                imageProvider: imageGenModel.edgeFunctionKey,
                imageCostUsd: imageCostUsd,
                captureMode: "fusion",
                imageCount: images.count,
                chefPersonality: chef.rawValue
            )

            if let start = startTime {
                logger.info("⏱ Fusion pipeline total: \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
            }
            logger.info("Fusion pipeline complete — recipe ready")

        } catch is CancellationError {
            logger.info("Fusion pipeline cancelled")
            await refundCreditIfNeeded()
            await LiveActivityManager.shared.cancelGeneration()
        } catch let error as EdgeFunctionError where error.isContentRejected {
            let reason = error.rejectionReason ?? "Image not suitable for recipe generation."
            logger.info("Fusion image rejected by server: \(reason)")
            state = .rejected(reason)
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        } catch let error as EdgeFunctionError where error.isInsufficientCredits {
            logger.warning("Insufficient credits — prompting purchase")
            state = .insufficientCredits
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        } catch {
            logger.error("Fusion pipeline failed: \(error)")
            await refundCreditIfNeeded()
            state = .failed(error.localizedDescription)
            await LiveActivityManager.shared.endGeneration(dishName: nil)
        }
    }

    // MARK: - Credit Refund

    /// Refunds the credit deducted during analysis if the pipeline fails or is cancelled after deduction.
    private func refundCreditIfNeeded() async {
        guard let pool = creditPool,
              let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            try await SupabaseManager.shared.client
                .rpc("refund_credit", params: ["p_user_id": userId, "p_pool": pool])
                .execute()
            logger.info("Credit refunded to pool: \(pool)")
            await UsageTracker.shared.syncCreditsFromServer()
        } catch {
            logger.error("Failed to refund credit: \(error)")
        }
        creditPool = nil
    }

    // MARK: - Analysis Request Builder

    private func buildAnalysisRequest(
        base64Images: [String],
        chef: ChefPersonality,
        hardExcluding: [String],
        softAvoiding: [String],
        budgetLimit: Double?,
        courseType: String?,
        cultureName: String? = nil,
        simplifyMode: Bool = false
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

        let userSkillLevel = UserDefaults.standard.string(forKey: "userSkillLevel")

        return AnalyzeImageRequest(
            images: base64Images,
            provider: "gemini",
            chef: chef.rawValue,
            customChefConfig: customConfig,
            dietaryPreferences: dietaryPrefs.isEmpty ? nil : dietaryPrefs.map(\.rawValue),
            hardExcluding: hardExcluding,
            softAvoiding: softAvoiding,
            budgetLimit: budgetLimit,
            courseType: courseType,
            cultureName: cultureName,
            simplifyMode: simplifyMode ? true : nil,
            skillLevel: userSkillLevel
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
