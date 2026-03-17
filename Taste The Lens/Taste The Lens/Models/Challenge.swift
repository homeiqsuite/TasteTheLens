import Foundation

// MARK: - Filter

enum ChallengeFilter: String, CaseIterable, Identifiable {
    case trending
    case new
    case endingSoon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trending: "Trending"
        case .new: "New"
        case .endingSoon: "Ending Soon"
        }
    }
}

// MARK: - DTOs

struct ChallengeDTO: Codable, Identifiable {
    let id: String
    let creatorId: String
    let recipeId: String
    let title: String
    let description: String?
    let inspirationImagePath: String?
    let dishImagePath: String?
    let createdAt: String
    let endsAt: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case recipeId = "recipe_id"
        case title
        case description
        case inspirationImagePath = "inspiration_image_path"
        case dishImagePath = "dish_image_path"
        case createdAt = "created_at"
        case endsAt = "ends_at"
        case status
    }
}

struct ChallengeSubmissionDTO: Codable, Identifiable {
    let id: String
    let challengeId: String
    let userId: String
    let photoUrl: String
    let caption: String?
    let upvoteCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case challengeId = "challenge_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
        case caption
        case upvoteCount = "upvote_count"
        case createdAt = "created_at"
    }
}

struct ChallengeUpvoteDTO: Codable {
    let id: String
    let submissionId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case id
        case submissionId = "submission_id"
        case userId = "user_id"
    }
}
