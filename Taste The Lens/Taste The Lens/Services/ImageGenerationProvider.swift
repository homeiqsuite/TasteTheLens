import Foundation
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ImageGen")

// MARK: - Model Selection

enum ImageGenerationModel: String, CaseIterable, Identifiable {
    case fluxPro = "flux-pro"
    case fluxSchnell = "flux-schnell"
    case imagen4 = "imagen-4"
    case imagen4Fast = "imagen-4-fast"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fluxPro: return "Flux Pro v1.1"
        case .fluxSchnell: return "Flux Schnell"
        case .imagen4: return "Imagen 4"
        case .imagen4Fast: return "Imagen 4 Fast"
        }
    }

    var provider: String {
        switch self {
        case .fluxPro, .fluxSchnell: return "Fal.ai"
        case .imagen4, .imagen4Fast: return "Google"
        }
    }

    var estimatedCost: String {
        switch self {
        case .fluxPro: return "~$0.050"
        case .fluxSchnell: return "~$0.003"
        case .imagen4: return "~$0.030"
        case .imagen4Fast: return "~$0.020"
        }
    }

    var qualityTier: String {
        switch self {
        case .fluxPro: return "Highest"
        case .imagen4: return "High"
        case .imagen4Fast: return "Good"
        case .fluxSchnell: return "Standard"
        }
    }
}

// MARK: - Provider Protocol

protocol ImageGenerationProviding: Sendable {
    func generateImage(prompt: String) async throws -> (Data, String)
}

extension FalAPIClient: ImageGenerationProviding {}

// MARK: - Factory

enum ImageGenerationFactory {
    static func client(for model: ImageGenerationModel) -> ImageGenerationProviding {
        switch model {
        case .fluxPro:
            return FalAPIClient()
        case .fluxSchnell:
            return FalSchnellClient()
        case .imagen4:
            return GeminiImageClient(fast: false)
        case .imagen4Fast:
            return GeminiImageClient(fast: true)
        }
    }
}

// MARK: - Fal.ai Flux Schnell

struct FalSchnellClient: ImageGenerationProviding, Sendable {
    private static let endpoint = URL(string: "https://fal.run/fal-ai/flux/schnell")!

    nonisolated func generateImage(prompt: String) async throws -> (Data, String) {
        logger.info("Generating image with Flux Schnell — prompt length: \(prompt.count)")
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "image_size": "landscape_16_9",
            "num_images": 1,
            "enable_safety_checker": true,
            "output_format": "jpeg"
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Key \(AppConfig.falAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown"
            logger.error("Flux Schnell error: \(errorBody)")
            throw FalAPIError.apiError("Flux Schnell error: \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let images = json["images"] as? [[String: Any]],
              let firstImage = images.first,
              let imageURLString = firstImage["url"] as? String,
              let imageURL = URL(string: imageURLString) else {
            throw FalAPIError.noImageGenerated
        }

        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        logger.info("Flux Schnell image downloaded: \(imageData.count) bytes")
        return (imageData, imageURLString)
    }
}

// MARK: - Gemini Imagen 4

struct GeminiImageClient: ImageGenerationProviding, Sendable {
    let fast: Bool

    private var modelId: String {
        fast ? "imagen-4.0-fast-generate-001" : "imagen-4.0-generate-001"
    }

    private var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):predict?key=\(AppConfig.geminiAPIKey)")!
    }

    nonisolated func generateImage(prompt: String) async throws -> (Data, String) {
        let label = fast ? "Imagen 4 Fast" : "Imagen 4"
        logger.info("Generating image with \(label) — prompt length: \(prompt.count)")

        let requestBody: [String: Any] = [
            "instances": [
                ["prompt": prompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "16:9",
                "personGeneration": "dont_allow"
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiAPIError.invalidResponse
            }
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown"
                logger.error("\(label) error (\(httpResponse.statusCode)): \(errorBody)")
                throw GeminiAPIError.apiError("\(label) error (\(httpResponse.statusCode)): \(errorBody)")
            }
            data = responseData
        } catch let error as GeminiAPIError {
            throw error
        } catch {
            logger.error("\(label) network error: \(error)")
            throw GeminiAPIError.networkError(error)
        }

        // Parse Imagen response: { "predictions": [{ "bytesBase64Encoded": "...", "mimeType": "..." }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let predictions = json["predictions"] as? [[String: Any]],
              let first = predictions.first,
              let base64String = first["bytesBase64Encoded"] as? String,
              let imageData = Data(base64Encoded: base64String) else {
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8"
            logger.error("Failed to parse \(label) response: \(raw.prefix(500))")
            throw GeminiAPIError.invalidResponse
        }

        logger.info("\(label) image generated: \(imageData.count) bytes")
        return (imageData, "imagen://generated/\(UUID().uuidString)")
    }
}
