import Foundation
import Supabase
import os

private let logger = makeLogger(category: "Analytics")

// MARK: - Payloads

struct CostEntryPayload: Encodable {
    let analysisProvider: String?
    let analysisModel: String?
    let analysisInputTokens: Int?
    let analysisOutputTokens: Int?
    let analysisCostUsd: Double?
    let imageProvider: String?
    let imageCostUsd: Double?
    let totalCostUsd: Double?
    let captureMode: String
    let imageCount: Int
    let chefPersonality: String
}

private struct TrackEventRequest: Encodable {
    let event: String
    let properties: [String: String]
    let costEntry: CostEntryPayload?
}

// MARK: - AnalyticsClient

/// Fire-and-forget analytics client. All methods are non-blocking;
/// errors are swallowed so analytics never disrupts the user experience.
actor AnalyticsClient {
    static let shared = AnalyticsClient()
    private init() {}

    // MARK: - General Events

    /// Track any named event with optional string properties.
    nonisolated func track(_ event: String, properties: [String: String] = [:]) {
        Task { await send(event: event, properties: properties, costEntry: nil) }
    }

    // MARK: - Recipe Generation Cost

    /// Track a completed recipe generation with full cost breakdown.
    nonisolated func trackRecipeGeneration(
        analysisProvider: String?,
        analysisModel: String?,
        analysisInputTokens: Int?,
        analysisOutputTokens: Int?,
        analysisCostUsd: Double?,
        imageProvider: String?,
        imageCostUsd: Double?,
        captureMode: String,   // "single" | "fusion"
        imageCount: Int,
        chefPersonality: String
    ) {
        let totalCost = (analysisCostUsd ?? 0) + (imageCostUsd ?? 0)

        let cost = CostEntryPayload(
            analysisProvider: analysisProvider,
            analysisModel: analysisModel,
            analysisInputTokens: analysisInputTokens,
            analysisOutputTokens: analysisOutputTokens,
            analysisCostUsd: analysisCostUsd,
            imageProvider: imageProvider,
            imageCostUsd: imageCostUsd,
            totalCostUsd: totalCost,
            captureMode: captureMode,
            imageCount: imageCount,
            chefPersonality: chefPersonality
        )

        let props: [String: String] = [
            "capture_mode": captureMode,
            "image_count": String(imageCount),
            "chef": chefPersonality,
            "analysis_provider": analysisProvider ?? "unknown",
            "image_provider": imageProvider ?? "unknown",
            "total_cost_usd": String(format: "%.6f", totalCost),
        ]

        Task { await send(event: "recipe_generation_completed", properties: props, costEntry: cost) }
    }

    // MARK: - Private

    private func send(event: String, properties: [String: String], costEntry: CostEntryPayload?) async {
        let baseURL = AppConfig.supabaseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/functions/v1/track-event") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        if AuthManager.shared.isAuthenticated,
           let session = try? await SupabaseManager.shared.client.auth.session {
            request.setValue(session.accessToken, forHTTPHeaderField: "x-user-token")
        }

        do {
            let payload = TrackEventRequest(event: event, properties: properties, costEntry: costEntry)
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                logger.warning("track-event \(event) returned \(http.statusCode)")
            }
        } catch {
            logger.warning("track-event error for '\(event)': \(error)")
        }
    }
}
