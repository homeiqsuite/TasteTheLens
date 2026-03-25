import Foundation
import os

private let logger = makeLogger(category: "FalAPI")

enum FalAPIError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case noImageGenerated

    var errorDescription: String? {
        switch self {
        case .networkError: return "Couldn't plate this one. Give it another shot."
        case .invalidResponse: return "Couldn't plate this one. Give it another shot."
        case .apiError(let message): return message
        case .noImageGenerated: return "Couldn't plate this one. Give it another shot."
        }
    }
}

struct FalAPIClient: Sendable {
    private static let endpoint = URL(string: "https://fal.run/fal-ai/flux-pro/v1.1")!

    nonisolated func generateImage(prompt: String) async throws -> (Data, String) {
        logger.info("Generating image with fal.ai — prompt length: \(prompt.count)")
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "image_size": "landscape_16_9",
            "num_inference_steps": 28,
            "guidance_scale": 3.5,
            "num_images": 1,
            "enable_safety_checker": true,
            "output_format": "jpeg"
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Key \(AppConfig.falAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120

        logger.info("Sending request to fal.ai...")
        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse")
                throw FalAPIError.invalidResponse
            }
            logger.info("fal.ai HTTP status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                logger.error("fal.ai error: \(errorBody)")
                throw FalAPIError.apiError("fal.ai error (\(httpResponse.statusCode)): \(errorBody)")
            }
            data = responseData
        } catch let error as FalAPIError {
            throw error
        } catch {
            logger.error("Network error calling fal.ai: \(error)")
            throw FalAPIError.networkError(error)
        }

        // Parse the response to get the image URL
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["images"] as? [[String: Any]],
              let firstImage = images.first,
              let imageURLString = firstImage["url"] as? String else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "non-UTF8"
            logger.error("Failed to parse fal.ai response: \(rawResponse.prefix(500))")
            throw FalAPIError.noImageGenerated
        }

        logger.info("fal.ai image URL: \(imageURLString)")

        // Download the generated image
        guard let imageURL = URL(string: imageURLString) else {
            throw FalAPIError.noImageGenerated
        }

        let imageData: Data
        do {
            let (downloadedData, _) = try await URLSession.shared.data(from: imageURL)
            imageData = downloadedData
            logger.info("Downloaded generated image: \(imageData.count) bytes")
        } catch {
            logger.error("Failed to download generated image: \(error)")
            throw FalAPIError.networkError(error)
        }

        return (imageData, imageURLString)
    }
}
