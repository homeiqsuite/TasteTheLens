import Foundation

// MARK: - Course Types

enum CourseType: String, CaseIterable, Identifiable, Codable {
    case amuse = "Amuse-Bouche"
    case appetizer = "Appetizer"
    case soup = "Soup"
    case salad = "Salad"
    case main = "Main Course"
    case dessert = "Dessert"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .amuse: "sparkle"
        case .appetizer: "leaf"
        case .soup: "mug"
        case .salad: "carrot"
        case .main: "fork.knife"
        case .dessert: "birthday.cake"
        }
    }
}

// MARK: - DTOs

struct TastingMenuDTO: Codable, Identifiable {
    let id: String
    let creatorId: String
    let theme: String
    let courseCount: Int
    let status: String
    let inviteCode: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case theme
        case courseCount = "course_count"
        case status
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MenuParticipantDTO: Codable {
    let menuId: String
    let userId: String
    let role: String
    let joinedAt: String

    enum CodingKeys: String, CodingKey {
        case menuId = "menu_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

struct MenuCourseDTO: Codable, Identifiable {
    let id: String
    let menuId: String
    let participantId: String?
    let recipeId: String?
    let courseType: String
    let courseOrder: Int
    let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case menuId = "menu_id"
        case participantId = "participant_id"
        case recipeId = "recipe_id"
        case courseType = "course_type"
        case courseOrder = "course_order"
        case addedAt = "added_at"
    }
}
