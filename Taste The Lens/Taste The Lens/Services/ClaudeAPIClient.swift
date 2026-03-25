import Foundation
import UIKit
import os

private let logger = makeLogger(category: "ClaudeAPI")

struct ClaudeRecipeResponse: Codable, Sendable {
    let dishName: String
    let description: String
    let sceneAnalysis: SceneAnalysis?
    let colorPalette: [String]?
    let imageGenerationPrompt: String
    let translationMatrix: [TranslationItem]
    let components: [RecipeComponent]
    let cookingInstructions: [String]?
    let platingSteps: [String]
    let sommelierPairing: SommelierPairing
    let baseServings: Int?
    let estimatedCalories: Int?
    let nutrition: NutritionInfo?

    enum CodingKeys: String, CodingKey {
        case dishName = "dish_name"
        case description
        case sceneAnalysis = "scene_analysis"
        case colorPalette = "color_palette"
        case imageGenerationPrompt = "image_generation_prompt"
        case translationMatrix = "translation_matrix"
        case components
        case cookingInstructions = "cooking_instructions"
        case platingSteps = "plating_steps"
        case sommelierPairing = "sommelier_pairing"
        case baseServings = "base_servings"
        case estimatedCalories = "estimated_calories"
        case nutrition
    }
}

enum ClaudeAPIError: LocalizedError {
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case jsonParseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .networkError: return "Connection timed out. Check your network and try again."
        case .invalidResponse: return "Our chef is momentarily unavailable. Try a different photo."
        case .apiError(let message): return message
        case .jsonParseError: return "Our chef is momentarily unavailable. Try a different photo."
        }
    }
}

struct ClaudeAPIClient: ImageAnalysisProvider, Sendable {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-20250514"

    // System prompt is now provided by ChefPersonality

    nonisolated func screenImage(_ image: UIImage) async throws -> ContentScreeningResult {
        // Claude doesn't have a separate screening endpoint — allow through
        return ContentScreeningResult(safe: true, reason: "Screening not available via Claude")
    }

    nonisolated func analyzeImage(_ image: UIImage, systemPrompt: String = ChefPersonality.current.systemPrompt) async throws -> (ClaudeRecipeResponse, String) {
        logger.info("Preparing image for Claude API...")
        guard let imageData = image.jpegDataForUpload() else {
            logger.error("Failed to create JPEG data from image")
            throw ClaudeAPIError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()
        logger.info("Image encoded: \(imageData.count) bytes, base64: \(base64Image.count) chars")

        let requestBody: [String: Any] = [
            "model": Self.model,
            "max_tokens": 8192,
            "temperature": 1.0,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Analyze this image. First, identify everything visible — every object, ingredient, text, and setting detail. Then create a delicious, home-cookable dish inspired by what you see. If you spot real ingredients, use them. Use only common grocery store ingredients."
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(AppConfig.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        logger.info("Sending request to Claude API...")
        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse")
                throw ClaudeAPIError.invalidResponse
            }
            logger.info("Claude HTTP status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                logger.error("Claude API error: \(errorBody)")
                throw ClaudeAPIError.apiError("Claude API error (\(httpResponse.statusCode)): \(errorBody)")
            }
            data = responseData
        } catch let error as ClaudeAPIError {
            throw error
        } catch {
            logger.error("Network error calling Claude: \(error)")
            throw ClaudeAPIError.networkError(error)
        }

        // Parse the Claude API response envelope
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = envelope["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "non-UTF8"
            logger.error("Failed to parse Claude envelope. Raw: \(rawResponse.prefix(500))")
            throw ClaudeAPIError.invalidResponse
        }

        logger.info("Claude text response length: \(text.count) chars")
        logger.debug("Claude raw text: \(text.prefix(200))...")

        // Parse the recipe JSON from the text content
        let rawJSON = text
        guard let jsonData = rawJSON.data(using: .utf8) else {
            throw ClaudeAPIError.jsonParseError("Could not encode response text")
        }

        do {
            let recipe = try JSONDecoder().decode(ClaudeRecipeResponse.self, from: jsonData)
            logger.info("Successfully decoded recipe: \(recipe.dishName)")
            return (recipe, rawJSON)
        } catch {
            logger.error("JSON decode error: \(error)")
            logger.error("Raw JSON that failed to parse: \(rawJSON.prefix(500))")
            throw ClaudeAPIError.jsonParseError(error.localizedDescription)
        }
    }
}
