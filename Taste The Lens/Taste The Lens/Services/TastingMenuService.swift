import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "TastingMenuService")

@Observable @MainActor
final class TastingMenuService {
    static let shared = TastingMenuService()

    var myMenus: [TastingMenuDTO] = []
    var isLoading = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var channels: [String: RealtimeChannelV2] = [:]

    private init() {}

    // MARK: - Create Menu

    func createMenu(theme: String, courseCount: Int, courseTypes: [CourseType]) async throws -> TastingMenuDTO {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        // Insert menu
        let menu: TastingMenuDTO = try await supabase
            .from("tasting_menus")
            .insert([
                "creator_id": userId,
                "theme": theme,
                "course_count": "\(courseCount)",
                "status": "draft"
            ])
            .select()
            .single()
            .execute()
            .value

        // Add creator as participant
        try await supabase
            .from("menu_participants")
            .insert([
                "menu_id": menu.id,
                "user_id": userId,
                "role": "creator"
            ])
            .execute()

        // Create empty course slots
        for (index, courseType) in courseTypes.prefix(courseCount).enumerated() {
            try await supabase
                .from("menu_courses")
                .insert([
                    "menu_id": menu.id,
                    "course_type": courseType.rawValue,
                    "course_order": "\(index)"
                ])
                .execute()
        }

        logger.info("Created tasting menu '\(theme)' with \(courseCount) courses")
        return menu
    }

    // MARK: - Fetch

    func fetchMyMenus() async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        isLoading = true
        defer { isLoading = false }

        // Get menu IDs where user is participant
        let participations: [MenuParticipantDTO] = try await supabase
            .from("menu_participants")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let menuIds = participations.map(\.menuId)
        guard !menuIds.isEmpty else {
            myMenus = []
            return
        }

        let menus: [TastingMenuDTO] = try await supabase
            .from("tasting_menus")
            .select()
            .in("id", values: menuIds)
            .order("updated_at", ascending: false)
            .execute()
            .value

        myMenus = menus
        logger.info("Fetched \(menus.count) tasting menus")
    }

    func fetchMenu(id: String) async throws -> TastingMenuDTO {
        let menu: TastingMenuDTO = try await supabase
            .from("tasting_menus")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return menu
    }

    func fetchCourses(menuId: String) async throws -> [MenuCourseDTO] {
        let courses: [MenuCourseDTO] = try await supabase
            .from("menu_courses")
            .select()
            .eq("menu_id", value: menuId)
            .order("course_order", ascending: true)
            .execute()
            .value
        return courses
    }

    func fetchParticipants(menuId: String) async throws -> [MenuParticipantDTO] {
        let participants: [MenuParticipantDTO] = try await supabase
            .from("menu_participants")
            .select()
            .eq("menu_id", value: menuId)
            .execute()
            .value
        return participants
    }

    // MARK: - Join

    func joinMenu(inviteCode: String) async throws -> TastingMenuDTO {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        // Look up menu by invite code
        let menu: TastingMenuDTO = try await supabase
            .from("tasting_menus")
            .select()
            .eq("invite_code", value: inviteCode)
            .single()
            .execute()
            .value

        // Add as participant
        try await supabase
            .from("menu_participants")
            .insert([
                "menu_id": menu.id,
                "user_id": userId,
                "role": "participant"
            ])
            .execute()

        logger.info("Joined tasting menu '\(menu.theme)' via invite code")
        return menu
    }

    // MARK: - Add Course

    func addCourse(menuId: String, courseOrder: Int, recipeId: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        try await supabase
            .from("menu_courses")
            .update([
                "recipe_id": recipeId,
                "participant_id": userId
            ])
            .eq("menu_id", value: menuId)
            .eq("course_order", value: courseOrder)
            .execute()

        // Update menu status if first course added
        try await supabase
            .from("tasting_menus")
            .update(["status": "in_progress", "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: menuId)
            .eq("status", value: "draft")
            .execute()

        logger.info("Added course \(courseOrder) to menu \(menuId)")
    }

    // MARK: - Delete

    func deleteMenu(id: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        // Delete courses, participants, then the menu itself
        try await supabase.from("menu_courses").delete().eq("menu_id", value: id).execute()
        try await supabase.from("menu_participants").delete().eq("menu_id", value: id).execute()
        try await supabase.from("tasting_menus").delete().eq("id", value: id).eq("creator_id", value: userId).execute()

        myMenus.removeAll { $0.id == id }
        logger.info("Deleted tasting menu \(id)")
    }

    // MARK: - Publish

    func publishMenu(id: String) async throws {
        try await supabase
            .from("tasting_menus")
            .update(["status": "published", "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id)
            .execute()

        logger.info("Published tasting menu \(id)")
    }

    // MARK: - Realtime

    func subscribeToMenu(id: String) {
        guard channels[id] == nil else { return }

        let channel = supabase.channel("menu-\(id)")

        let onInsert = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "menu_courses",
            filter: .eq("menu_id", value: id)
        )

        let onUpdate = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "menu_courses",
            filter: .eq("menu_id", value: id)
        )

        Task {
            await channel.subscribe()
            logger.info("Subscribed to realtime for menu \(id)")

            async let inserts: Void = {
                for await _ in onInsert {
                    logger.info("Realtime: course inserted on menu \(id)")
                    NotificationCenter.default.post(name: .menuCourseUpdated, object: nil, userInfo: ["menuId": id])
                }
            }()

            async let updates: Void = {
                for await _ in onUpdate {
                    logger.info("Realtime: course updated on menu \(id)")
                    NotificationCenter.default.post(name: .menuCourseUpdated, object: nil, userInfo: ["menuId": id])
                }
            }()

            _ = await (inserts, updates)
        }

        channels[id] = channel
    }

    func unsubscribeFromMenu(id: String) {
        if let channel = channels.removeValue(forKey: id) {
            Task {
                await channel.unsubscribe()
                logger.info("Unsubscribed from realtime for menu \(id)")
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let menuCourseUpdated = Notification.Name("menuCourseUpdated")
}

// MARK: - Errors

enum TastingMenuError: LocalizedError {
    case notAuthenticated
    case menuNotFound
    case menuFull

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in to participate in tasting menus"
        case .menuNotFound: "Tasting menu not found"
        case .menuFull: "This tasting menu is already full"
        }
    }
}
