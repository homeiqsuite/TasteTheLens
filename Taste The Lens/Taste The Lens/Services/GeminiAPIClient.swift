import Foundation
import UIKit
import os

private let logger = makeLogger(category: "GeminiAPI")

enum GeminiAPIError: LocalizedError {
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case jsonParseError(String)
    case contentRejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .networkError: return "Connection timed out. Check your network and try again."
        case .invalidResponse: return "Our chef is momentarily unavailable. Try a different photo."
        case .apiError(let message): return message
        case .jsonParseError: return "Our chef is momentarily unavailable. Try a different photo."
        case .contentRejected(let reason): return reason
        }
    }
}

struct ContentScreeningResult: Codable {
    let safe: Bool
    let reason: String
}

struct GeminiAPIClient: ImageAnalysisProvider, Sendable {
    private static let model = "gemini-2.5-flash"

    private static var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(AppConfig.geminiAPIKey)")!
    }

    private static let screeningPrompt = """
    Content safety screener for a food/recipe app. Check if the image is appropriate for culinary inspiration.

    REJECT (safe: false) if:
    - Real, identifiable people (selfies, portraits, group photos)
    - Children as primary subject
    - Live animals as primary subject (packaged meat/seafood is fine)

    ALLOW (safe: true) if:
    - Food, ingredients, drinks, kitchens, restaurants, menus
    - Objects, products, art, landscapes, architecture, nature, abstract
    - Fictional characters, cartoons, illustrations, statues, sculptures
    - Stylized/drawn people (not real photos of identifiable people)
    - People incidental/background (e.g., street market focused on food stalls)
    - Packaged products with people on labels
    - Hands only (no face visible)

    CRITICAL: Output ONLY raw JSON, no markdown, no explanation, no code fences.
    """

    // System prompt is now provided by ChefPersonality

    nonisolated func analyzeImage(_ image: UIImage, systemPrompt: String = ChefPersonality.current.systemPrompt) async throws -> (ClaudeRecipeResponse, String) {
        logger.info("Preparing image for Gemini API...")
        guard let imageData = image.jpegDataForUpload() else {
            logger.error("Failed to create JPEG data from image")
            throw GeminiAPIError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()
        logger.info("Image encoded: \(imageData.count) bytes, base64: \(base64Image.count) chars")

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": "Analyze this image. First, identify everything visible — every object, ingredient, text, and setting detail. Then create a delicious, home-cookable dish inspired by what you see. If you spot real ingredients, use them. Use only common grocery store ingredients. Return ONLY the JSON, no markdown code fences."
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.9,
                "maxOutputTokens": 8192,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        logger.info("Sending request to Gemini API...")
        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse")
                throw GeminiAPIError.invalidResponse
            }
            logger.info("Gemini HTTP status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                logger.error("Gemini API error: \(errorBody)")
                throw GeminiAPIError.apiError("Gemini API error (\(httpResponse.statusCode)): \(errorBody)")
            }
            data = responseData
        } catch let error as GeminiAPIError {
            throw error
        } catch {
            logger.error("Network error calling Gemini: \(error)")
            throw GeminiAPIError.networkError(error)
        }

        // Parse Gemini response envelope
        // Structure: { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = envelope["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "non-UTF8"
            logger.error("Failed to parse Gemini envelope. Raw: \(rawResponse.prefix(500))")
            throw GeminiAPIError.invalidResponse
        }

        logger.info("Gemini text response length: \(text.count) chars")
        logger.debug("Gemini raw text: \(text.prefix(200))...")

        let jsonText = Self.stripMarkdownFences(text)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw GeminiAPIError.jsonParseError("Could not encode response text")
        }

        do {
            let recipe = try JSONDecoder().decode(ClaudeRecipeResponse.self, from: jsonData)
            logger.info("Successfully decoded recipe: \(recipe.dishName)")
            return (recipe, jsonText)
        } catch {
            logger.error("JSON decode error: \(error)")
            logger.error("Raw JSON that failed to parse: \(jsonText.prefix(500))")
            throw GeminiAPIError.jsonParseError(error.localizedDescription)
        }
    }

    // MARK: - Multi-Image Analysis (Fusion Mode)

    nonisolated func analyzeImages(_ images: [UIImage], systemPrompt: String = ChefPersonality.current.systemPrompt) async throws -> (ClaudeRecipeResponse, String) {
        logger.info("Preparing \(images.count) images for Gemini Fusion analysis...")

        var parts: [[String: Any]] = []
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegDataForUpload() else {
                logger.error("Failed to create JPEG data from fusion image \(index)")
                throw GeminiAPIError.invalidImage
            }
            let base64Image = imageData.base64EncodedString()
            logger.info("Fusion image \(index) encoded: \(imageData.count) bytes")
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64Image
                ]
            ])
        }

        parts.append([
            "text": "Analyze ALL of these images together. Identify everything visible in each — objects, ingredients, text, settings. Create ONE cohesive, delicious, home-cookable dish that FUSES the visual DNA of all images. Blend colors, textures, moods, and any real ingredients you spot across all photos. The dish should feel like a creative fusion of these visual worlds. Use only common grocery store ingredients. Return ONLY the JSON, no markdown code fences."
        ])

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                ["parts": parts]
            ],
            "generationConfig": [
                "temperature": 0.9,
                "maxOutputTokens": 8192,
                "responseMimeType": "application/json"
            ]
        ]

        let data = try await sendGeminiRequest(requestBody, timeout: 90)
        return try parseRecipeResponse(from: data)
    }

    // MARK: - Multi-Image Screening (Fusion Mode)

    nonisolated func screenImages(_ images: [UIImage]) async throws -> ContentScreeningResult {
        logger.info("Screening \(images.count) images for content safety...")

        return try await withThrowingTaskGroup(of: ContentScreeningResult.self) { group in
            for image in images {
                group.addTask {
                    try await self.screenImage(image)
                }
            }

            for try await result in group {
                if !result.safe {
                    group.cancelAll()
                    return result
                }
            }

            return ContentScreeningResult(safe: true, reason: "All images passed screening")
        }
    }

    // MARK: - Content Screening

    nonisolated func screenImage(_ image: UIImage) async throws -> ContentScreeningResult {
        logger.info("Screening image for content safety...")
        guard let imageData = image.jpegDataForUpload() else {
            throw GeminiAPIError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": Self.screeningPrompt]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": "Screen this image. Output: {\"safe\":true/false,\"reason\":\"brief\"}"
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 256,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 15

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // If screening API fails, allow through — Gemini's own safety filters provide a backstop
                logger.warning("Screening API returned non-200, allowing image through (downstream safety filters active)")
                return ContentScreeningResult(safe: true, reason: "Screening unavailable, passed through to generation")
            }
            data = responseData
        } catch {
            logger.warning("Screening network error, allowing image through: \(error)")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable, passed through to generation")
        }

        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = envelope["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            logger.warning("Could not parse screening response, allowing image through")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable, passed through to generation")
        }

        // Extract JSON from the response text — the model sometimes wraps it in
        // markdown fences or adds a preamble like "Here is the JSON:".
        let jsonString: String
        if let openBrace = text.firstIndex(of: "{"),
           let closeBrace = text.lastIndex(of: "}") {
            jsonString = String(text[openBrace...closeBrace])
        } else {
            logger.warning("Screening response contained no JSON object, allowing image through. Text: \(text.prefix(200))")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable, passed through to generation")
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            logger.warning("Could not encode screening JSON string to data, allowing image through")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable, passed through to generation")
        }

        do {
            let result = try JSONDecoder().decode(ContentScreeningResult.self, from: jsonData)
            logger.info("Screening result: safe=\(result.safe), reason=\(result.reason)")
            return result
        } catch {
            logger.warning("Could not decode screening result, allowing image through: \(error). Text: \(jsonString.prefix(200))")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable, passed through to generation")
        }
    }

    // MARK: - Shared Helpers

    private nonisolated func sendGeminiRequest(_ requestBody: [String: Any], timeout: TimeInterval = 60) async throws -> Data {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = timeout

        logger.info("Sending request to Gemini API...")
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse")
                throw GeminiAPIError.invalidResponse
            }
            logger.info("Gemini HTTP status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                logger.error("Gemini API error: \(errorBody)")
                throw GeminiAPIError.apiError("Gemini API error (\(httpResponse.statusCode)): \(errorBody)")
            }
            return responseData
        } catch let error as GeminiAPIError {
            throw error
        } catch {
            logger.error("Network error calling Gemini: \(error)")
            throw GeminiAPIError.networkError(error)
        }
    }

    /// Strips markdown code fences (```, ~~~) from LLM response text.
    static func stripMarkdownFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip opening fence: ```json, ```JSON, ~~~json, ``` or ~~~
        if let range = result.range(of: #"^(`{3,}|~{3,})\w*\s*"#, options: .regularExpression) {
            result = String(result[range.upperBound...])
        }
        // Strip closing fence
        if let range = result.range(of: #"\s*(`{3,}|~{3,})\s*$"#, options: .regularExpression) {
            result = String(result[result.startIndex..<range.lowerBound])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func parseRecipeResponse(from data: Data) throws -> (ClaudeRecipeResponse, String) {
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = envelope["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "non-UTF8"
            logger.error("Failed to parse Gemini envelope. Raw: \(rawResponse.prefix(500))")
            throw GeminiAPIError.invalidResponse
        }

        logger.info("Gemini text response length: \(text.count) chars")
        logger.debug("Gemini raw text: \(text.prefix(200))...")

        let jsonText = Self.stripMarkdownFences(text)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw GeminiAPIError.jsonParseError("Could not encode response text")
        }

        do {
            let recipe = try JSONDecoder().decode(ClaudeRecipeResponse.self, from: jsonData)
            logger.info("Successfully decoded recipe: \(recipe.dishName)")
            return (recipe, jsonText)
        } catch {
            logger.error("JSON decode error: \(error)")
            logger.error("Raw JSON that failed to parse: \(jsonText.prefix(500))")
            throw GeminiAPIError.jsonParseError(error.localizedDescription)
        }
    }
}
