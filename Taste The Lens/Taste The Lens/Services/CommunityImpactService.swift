import Foundation
import Supabase
import os

private let logger = makeLogger(category: "CommunityImpact")

/// Tracks community-wide recipe generation milestones and corporate donation stats.
@Observable @MainActor
final class CommunityImpactService {
    static let shared = CommunityImpactService()

    var totalGenerations: Int = 0
    var totalMealsDonated: Int = 0
    var isLoaded = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Fetch

    /// Fetches the current community stats from Supabase.
    func fetchStats() async {
        do {
            let rows: [CommunityStatsDTO] = try await supabase
                .from("community_stats")
                .select()
                .execute()
                .value

            if let stats = rows.first {
                totalGenerations = stats.totalGenerations
                totalMealsDonated = stats.totalMealsDonated
                isLoaded = true
                logger.info("Community stats loaded — \(stats.totalGenerations) generations, \(stats.totalMealsDonated) meals donated")
            }
        } catch {
            logger.error("Failed to fetch community stats: \(error.localizedDescription)")
        }
    }

    // MARK: - Increment Generation

    /// Call after each recipe generation to increment the community counter.
    func recordGeneration() async {
        do {
            let result: IncrementResult = try await supabase
                .rpc("increment_generation")
                .execute()
                .value

            totalGenerations = result.totalGenerations
            totalMealsDonated = result.totalMealsDonated
            logger.info("Generation recorded — now \(result.totalGenerations) total, \(result.totalMealsDonated) meals")
        } catch {
            logger.error("Failed to record generation: \(error.localizedDescription)")
        }
    }

}

// MARK: - DTOs

private struct CommunityStatsDTO: Decodable {
    let totalGenerations: Int
    let totalMealsDonated: Int

    enum CodingKeys: String, CodingKey {
        case totalGenerations = "total_generations"
        case totalMealsDonated = "total_meals_donated"
    }
}

private struct IncrementResult: Decodable {
    let totalGenerations: Int
    let totalMealsDonated: Int

    enum CodingKeys: String, CodingKey {
        case totalGenerations = "total_generations"
        case totalMealsDonated = "total_meals_donated"
    }
}

