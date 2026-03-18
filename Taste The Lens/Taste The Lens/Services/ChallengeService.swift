import Foundation
import UIKit
import Supabase
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ChallengeService")

@Observable @MainActor
final class ChallengeService {
    static let shared = ChallengeService()

    var challenges: [ChallengeDTO] = []
    var isLoading = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Create Challenge

    func createChallenge(recipe: Recipe) async throws -> ChallengeDTO {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else {
            throw ChallengeError.notAuthenticated
        }

        let recipeId = recipe.remoteId ?? recipe.id.uuidString

        // Upload images to challenge-photos bucket
        var inspirationPath: String?
        var dishPath: String?

        let inspirationData = recipe.inspirationImageData
        if !inspirationData.isEmpty {
            let path = "\(userId)/\(recipeId)/inspiration.jpg"
            try await supabase.storage
                .from("challenge-photos")
                .upload(path, data: inspirationData, options: .init(contentType: "image/jpeg", upsert: true))
            inspirationPath = path
        }

        if let dishData = recipe.generatedDishImageData {
            let path = "\(userId)/\(recipeId)/dish.jpg"
            try await supabase.storage
                .from("challenge-photos")
                .upload(path, data: dishData, options: .init(contentType: "image/jpeg", upsert: true))
            dishPath = path
        }

        let endsAt = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)

        let challenge: ChallengeDTO = try await supabase
            .from("challenges")
            .insert([
                "creator_id": userId,
                "recipe_id": recipeId,
                "title": recipe.dishName,
                "description": recipe.recipeDescription,
                "inspiration_image_path": inspirationPath ?? "",
                "dish_image_path": dishPath ?? "",
                "status": "active",
                "ends_at": endsAt
            ])
            .select()
            .single()
            .execute()
            .value

        logger.info("Created challenge: \(challenge.id)")
        return challenge
    }

    // MARK: - Fetch Challenges

    func fetchChallenges(filter: ChallengeFilter) async throws {
        isLoading = true
        defer { isLoading = false }

        let orderColumn: String
        let ascending: Bool

        switch filter {
        case .trending:
            orderColumn = "created_at"
            ascending = false
        case .new:
            orderColumn = "created_at"
            ascending = false
        case .endingSoon:
            orderColumn = "ends_at"
            ascending = true
        }

        let result: [ChallengeDTO] = try await supabase
            .from("challenges")
            .select()
            .eq("status", value: "active")
            .order(orderColumn, ascending: ascending)
            .limit(20)
            .execute()
            .value

        challenges = result
        logger.info("Fetched \(result.count) challenges (filter: \(filter.rawValue))")
    }

    // MARK: - Fetch Submissions

    func fetchSubmissions(challengeId: String) async throws -> [ChallengeSubmissionDTO] {
        let result: [ChallengeSubmissionDTO] = try await supabase
            .from("challenge_submissions")
            .select()
            .eq("challenge_id", value: challengeId)
            .order("upvote_count", ascending: false)
            .execute()
            .value

        return result
    }

    // MARK: - Submit Attempt

    func submitAttempt(challengeId: String, photoData: Data, caption: String?) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else {
            throw ChallengeError.notAuthenticated
        }

        // Upload photo
        let path = "\(userId)/\(challengeId)/submission.jpg"
        try await supabase.storage
            .from("challenge-photos")
            .upload(path, data: photoData, options: .init(contentType: "image/jpeg", upsert: true))

        let photoUrl = try supabase.storage
            .from("challenge-photos")
            .getPublicURL(path: path)
            .absoluteString

        // Insert submission
        try await supabase
            .from("challenge_submissions")
            .insert([
                "challenge_id": challengeId,
                "user_id": userId,
                "photo_url": photoUrl,
                "caption": caption ?? ""
            ])
            .execute()

        logger.info("Submitted attempt for challenge \(challengeId)")
    }

    // MARK: - Upvote

    func upvote(submissionId: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw ChallengeError.notAuthenticated
        }

        try await supabase.rpc("upvote_submission", params: [
            "p_submission_id": submissionId,
            "p_user_id": userId
        ]).execute()

        logger.info("Upvoted submission \(submissionId)")
    }

    func removeUpvote(submissionId: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw ChallengeError.notAuthenticated
        }

        try await supabase.rpc("remove_upvote", params: [
            "p_submission_id": submissionId,
            "p_user_id": userId
        ]).execute()

        logger.info("Removed upvote from submission \(submissionId)")
    }

    func hasUpvoted(submissionId: String) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return false }

        do {
            let result: [ChallengeUpvoteDTO] = try await supabase
                .from("challenge_upvotes")
                .select()
                .eq("submission_id", value: submissionId)
                .eq("user_id", value: userId)
                .execute()
                .value
            return !result.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Image Loading

    func loadImage(path: String) async -> UIImage? {
        guard !path.isEmpty else { return nil }
        do {
            let data = try await supabase.storage
                .from("challenge-photos")
                .download(path: path)
            return UIImage(data: data)
        } catch {
            logger.error("Failed to load challenge image: \(error)")
            return nil
        }
    }

    func getPublicURL(path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        return try? supabase.storage
            .from("challenge-photos")
            .getPublicURL(path: path)
    }
}

// MARK: - Errors

enum ChallengeError: LocalizedError {
    case notAuthenticated
    case invalidRecipe

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in to participate in challenges"
        case .invalidRecipe: "Recipe must be saved before creating a challenge"
        }
    }
}
