import Foundation
import UIKit
import Supabase
import os

private let logger = makeLogger(category: "ChallengeService")

@Observable @MainActor
final class ChallengeService {
    static let shared = ChallengeService()

    var challenges: [ChallengeDTO] = []
    var isLoading = false
    var hasMorePastChallenges = false

    // Dashboard-specific state (decoupled from feed)
    var dashboardChallenges: [ChallengeDTO] = []
    var dashboardState: DashboardChallengeState = .loading

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
            let compressed = UIImage.compressForCloudUpload(inspirationData)
            try await supabase.storage
                .from("challenge-photos")
                .upload(path, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))
            inspirationPath = path
        }

        if let dishData = recipe.generatedDishImageData {
            let path = "\(userId)/\(recipeId)/dish.jpg"
            let compressed = UIImage.compressForCloudUpload(dishData)
            try await supabase.storage
                .from("challenge-photos")
                .upload(path, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))
            dishPath = path
        }

        let durationHours = RemoteConfigManager.shared.challengeDurationHours
        let endsAt = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .hour, value: durationHours, to: Date())!)

        let keywords = Self.extractKeywords(from: recipe)

        struct ChallengeInsert: Encodable {
            let creator_id: String
            let recipe_id: String
            let title: String
            let description: String
            let inspiration_image_path: String
            let dish_image_path: String
            let status: String
            let ends_at: String
            let keywords: [String]
        }

        let challenge: ChallengeDTO = try await supabase
            .from("challenges")
            .insert(ChallengeInsert(
                creator_id: userId,
                recipe_id: recipeId,
                title: recipe.dishName,
                description: recipe.recipeDescription,
                inspiration_image_path: inspirationPath ?? "",
                dish_image_path: dishPath ?? "",
                status: "active",
                ends_at: endsAt,
                keywords: keywords
            ))
            .select()
            .single()
            .execute()
            .value

        logger.info("Created challenge: \(challenge.id)")
        AnalyticsClient.shared.track("challenge_created", properties: [
            "challenge_id": challenge.id,
            "recipe_id": recipeId,
        ])
        return challenge
    }

    // MARK: - Fetch Challenges

    func fetchChallenges(filter: ChallengeFilter, offset: Int = 0) async throws {
        isLoading = true
        defer { isLoading = false }

        let nowISO = ISO8601DateFormatter().string(from: Date())
        let pageSize = 20

        let result: [ChallengeDTO]

        if filter == .past {
            result = try await supabase
                .from("challenges")
                .select()
                .or("status.eq.completed,ends_at.lt.\(nowISO)")
                .order("ends_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            hasMorePastChallenges = result.count == pageSize
        } else {
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
            case .past:
                fatalError("Handled above")
            }

            result = try await supabase
                .from("challenges")
                .select()
                .eq("status", value: "active")
                .gt("ends_at", value: nowISO)
                .order(orderColumn, ascending: ascending)
                .limit(pageSize)
                .execute()
                .value
        }

        if offset > 0 {
            challenges.append(contentsOf: result)
        } else {
            challenges = result
        }
        logger.info("Fetched \(result.count) challenges (filter: \(filter.rawValue), offset: \(offset))")
    }

    // MARK: - Dashboard Challenges

    func fetchDashboardChallenges() async {
        let nowISO = ISO8601DateFormatter().string(from: Date())

        do {
            let active: [ChallengeDTO] = try await supabase
                .from("challenges")
                .select()
                .eq("status", value: "active")
                .gt("ends_at", value: nowISO)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value

            if !active.isEmpty {
                dashboardChallenges = active
                dashboardState = .activeChallenges
            } else {
                // Check if any past challenges exist
                let past: [ChallengeDTO] = try await supabase
                    .from("challenges")
                    .select()
                    .or("status.eq.completed,ends_at.lt.\(nowISO)")
                    .limit(1)
                    .execute()
                    .value

                dashboardChallenges = []
                dashboardState = past.isEmpty ? .noChallengesAtAll : .noActiveButHasPast
            }
        } catch {
            if (error as? URLError)?.code == .cancelled || error is CancellationError { return }
            logger.error("Failed to fetch dashboard challenges: \(error)")
            dashboardChallenges = []
            dashboardState = .noChallengesAtAll
        }
    }

    // MARK: - Fetch Submissions

    func fetchSubmissions(challengeId: String) async throws -> [ChallengeSubmissionDTO] {
        let result: [ChallengeSubmissionDTO] = try await supabase
            .from("challenge_submissions_with_user")
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

        // Upload photo (compressed for cloud storage)
        let path = "\(userId)/\(challengeId)/submission.jpg"
        let compressed = UIImage.compressForCloudUpload(photoData)
        try await supabase.storage
            .from("challenge-photos")
            .upload(path, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))

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
        AnalyticsClient.shared.track("challenge_submission_created", properties: [
            "challenge_id": challengeId,
        ])
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
        AnalyticsClient.shared.track("challenge_upvoted", properties: [
            "submission_id": submissionId,
        ])
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

    // MARK: - Declare Winner

    func declareWinner(challengeId: String, submissionId: String, challengeTitle: String) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw ChallengeError.notAuthenticated
        }

        try await supabase.functions.invoke("challenge-declare-winner", options: .init(body: [
            "challengeId": challengeId,
            "winnerSubmissionId": submissionId,
            "challengeTitle": challengeTitle
        ] as [String: String]))

        logger.info("Declared winner \(submissionId) for challenge \(challengeId)")
    }

    // MARK: - Has Submitted

    func hasSubmitted(challengeId: String) async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else { return false }

        do {
            let result: [ChallengeSubmissionDTO] = try await supabase
                .from("challenge_submissions")
                .select()
                .eq("challenge_id", value: challengeId)
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            return !result.isEmpty
        } catch {
            logger.error("Failed to check submission status: \(error)")
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

    // MARK: - Ratings

    func rateSubmission(submissionId: String, stars: Int) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else {
            throw ChallengeError.notAuthenticated
        }
        struct RatingUpsert: Encodable {
            let submission_id: String
            let user_id: String
            let stars: Int
        }
        try await supabase
            .from("challenge_submission_ratings")
            .upsert(RatingUpsert(submission_id: submissionId, user_id: userId, stars: stars),
                    onConflict: "submission_id,user_id")
            .execute()
        logger.info("Rated submission \(submissionId) with \(stars) stars")
    }

    func getUserRating(submissionId: String) async -> Int? {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else { return nil }
        do {
            struct RatingRow: Decodable { let stars: Int }
            let result: [RatingRow] = try await supabase
                .from("challenge_submission_ratings")
                .select("stars")
                .eq("submission_id", value: submissionId)
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            return result.first?.stars
        } catch {
            return nil
        }
    }

    // MARK: - Fetch Challenge Recipe

    func fetchChallengeRecipe(recipeId: String) async throws -> Recipe {
        let dto: SupabaseRecipeDTO = try await supabase
            .from("recipes")
            .select()
            .eq("id", value: recipeId)
            .single()
            .execute()
            .value

        // Download inspiration image
        var inspirationData = Data()
        if let path = dto.inspirationImagePath {
            do {
                inspirationData = try await supabase.storage
                    .from("inspiration-images")
                    .download(path: path)
            } catch {
                logger.warning("Failed to download inspiration image: \(error)")
            }
        }

        // Download dish image
        var dishImageData: Data?
        if let path = dto.dishImagePath {
            do {
                dishImageData = try await supabase.storage
                    .from("dish-images")
                    .download(path: path)
            } catch {
                logger.warning("Failed to download dish image: \(error)")
            }
        }

        return dto.toRecipe(inspirationData: inspirationData, dishImageData: dishImageData)
    }

    // MARK: - Keyword Extraction

    static func extractKeywords(from recipe: Recipe) -> [String] {
        var keywords: Set<String> = ["AI-Generated"]

        // Chef-based
        let chef = ChefPersonality.current
        switch chef {
        case .dooby: keywords.insert("Comfort Food")
        case .grizzly: keywords.insert("Outdoor")
        case .beginner: keywords.insert("Beginner-Friendly")
        case .familyChef: keywords.insert("Family-Friendly")
        default: keywords.insert("World Cuisine")
        }

        // Collect all ingredient text
        let allIngredients = recipe.components
            .flatMap(\.ingredients)
            .joined(separator: " ")
            .lowercased()
        let allSteps = recipe.cookingSteps
            .map(\.instruction)
            .joined(separator: " ")
            .lowercased()
        let allText = allIngredients + " " + allSteps + " " + recipe.recipeDescription.lowercased()

        // Spicy
        let spicyTerms = ["jalapeño", "jalapeno", "habanero", "serrano", "sriracha", "chili", "chilli", "cayenne", "hot sauce", "red pepper flake", "ghost pepper"]
        if spicyTerms.contains(where: { allIngredients.contains($0) }) {
            keywords.insert("Spicy")
        }

        // Sweet
        let sweetTerms = ["chocolate", "caramel", "honey", "maple syrup", "sugar", "vanilla", "dessert", "cake", "cookie", "brownie", "ice cream"]
        if sweetTerms.contains(where: { allText.contains($0) }) {
            keywords.insert("Sweet")
        }

        // Savory & Umami
        let umamiTerms = ["miso", "soy sauce", "fish sauce", "anchovy", "worcestershire", "parmesan", "mushroom", "umami"]
        if umamiTerms.contains(where: { allIngredients.contains($0) }) {
            keywords.insert("Savory")
        }

        // Cooking method
        if allSteps.contains("grill") || allSteps.contains("bbq") || allSteps.contains("barbecue") {
            keywords.insert("Grilled")
        }
        if allSteps.contains("bake") || allSteps.contains("oven") || allSteps.contains("roast") {
            keywords.insert("Baked")
        }
        if allSteps.contains("fry") || allSteps.contains("crisp") || allSteps.contains("crunch") {
            keywords.insert("Crispy")
        }

        // Time-based (parse numeric minutes from cookTime)
        if let cookTime = recipe.cookTime {
            let digits = cookTime.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let minutes = Int(digits) {
                if minutes < 25 { keywords.insert("Quick") }
                else if minutes > 60 { keywords.insert("Slow-Cooked") }
            }
        }

        // Cap at 5, always keeping AI-Generated
        var result = Array(keywords.filter { $0 != "AI-Generated" }.prefix(4))
        result.append("AI-Generated")
        return result
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
