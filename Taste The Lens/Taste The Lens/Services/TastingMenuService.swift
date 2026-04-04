import Foundation
import Supabase
import os

private let logger = makeLogger(category: "TastingMenuService")

@Observable @MainActor
final class TastingMenuService {
    static let shared = TastingMenuService()

    var myMenus: [TastingMenuDTO] = []
    var isLoading = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private var channels: [String: RealtimeChannelV2] = [:]

    private init() {}

    // MARK: - Create Menu

    func createMenu(
        theme: String,
        courseCount: Int,
        courseTypes: [CourseType],
        eventDate: Date? = nil
    ) async throws -> TastingMenuDTO {
        guard AuthManager.shared.currentUser != nil else {
            throw TastingMenuError.notAuthenticated
        }

        struct CreateTastingMenuRequest: Encodable {
            let theme: String
            let courseCount: Int
            let courseTypes: [String]
            let eventDate: String?
        }

        let isoFormatter = ISO8601DateFormatter()
        let menu: TastingMenuDTO = try await supabase.functions.invoke(
            "create-tasting-menu",
            options: .init(body: CreateTastingMenuRequest(
                theme: theme,
                courseCount: courseCount,
                courseTypes: courseTypes.prefix(courseCount).map(\.rawValue),
                eventDate: eventDate.map { isoFormatter.string(from: $0) }
            ))
        )

        logger.info("Created tasting menu '\(theme)' with \(courseCount) courses")
        AnalyticsClient.shared.track("tasting_menu_created", properties: [
            "menu_id": menu.id,
            "course_count": String(courseCount),
        ])
        return menu
    }

    // MARK: - Fetch

    // #11: Parallel fetch instead of two sequential queries
    func fetchMyMenus() async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        isLoading = true
        defer { isLoading = false }

        // Fetch participations and menus in parallel
        async let participationsResult: [MenuParticipantDTO] = supabase
            .from("menu_participants")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let participations = try await participationsResult
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
        guard AuthManager.shared.currentUser != nil else {
            throw TastingMenuError.notAuthenticated
        }

        let response = try await supabase
            .rpc("join_menu_by_invite_code", params: ["p_invite_code": inviteCode])
            .execute()

        let menu = try JSONDecoder().decode(TastingMenuDTO.self, from: response.data)

        logger.info("Joined tasting menu '\(menu.theme)' via invite code")
        AnalyticsClient.shared.track("tasting_menu_joined", properties: [
            "menu_id": menu.id,
        ])
        return menu
    }

    // MARK: - Leave Menu (#22)

    func leaveMenu(id: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        try await supabase
            .rpc("leave_menu", params: ["p_menu_id": id, "p_user_id": userId])
            .execute()

        myMenus.removeAll { $0.id == id }
        logger.info("Left tasting menu \(id)")
        AnalyticsClient.shared.track("tasting_menu_left", properties: ["menu_id": id])
    }

    // MARK: - Add Course

    func addCourse(menuId: String, courseOrder: Int, recipeId: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            logger.error("addCourse — not authenticated")
            throw TastingMenuError.notAuthenticated
        }

        logger.info("addCourse — menuId: \(menuId), courseOrder: \(courseOrder), recipeId: \(recipeId)")

        // #1: Check if course was already claimed by another chef before attempting update
        let existingCourse: [MenuCourseDTO] = try await supabase
            .from("menu_courses")
            .select()
            .eq("menu_id", value: menuId)
            .eq("course_order", value: courseOrder)
            .execute()
            .value

        if let course = existingCourse.first, course.recipeId != nil {
            logger.error("addCourse — course \(courseOrder) already has a recipe (race condition)")
            throw TastingMenuError.courseAlreadyClaimed
        }

        let updateResult = try await supabase
            .from("menu_courses")
            .update([
                "recipe_id": recipeId,
                "participant_id": userId
            ])
            .eq("menu_id", value: menuId)
            .eq("course_order", value: courseOrder)
            .select()
            .execute()

        logger.info("addCourse — update response status: \(updateResult.status)")

        let rows = try? JSONDecoder().decode([[String: String]].self, from: updateResult.data)
        if rows?.isEmpty != false {
            // Row was taken by another participant between our check and update
            logger.error("addCourse — update matched no rows (likely race condition) for menuId: \(menuId), courseOrder: \(courseOrder)")
            throw TastingMenuError.courseAlreadyClaimed
        }

        // Update menu status if first course added
        try await supabase
            .from("tasting_menus")
            .update(["status": "in_progress", "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: menuId)
            .eq("status", value: "draft")
            .execute()

        logger.info("Added course \(courseOrder) to menu \(menuId) successfully")
        AnalyticsClient.shared.track("tasting_menu_course_added", properties: [
            "menu_id": menuId,
            "course_order": String(courseOrder),
            "recipe_id": recipeId,
        ])

        // #20: Notify other participants (fire-and-forget)
        if let menu = myMenus.first(where: { $0.id == menuId }) {
            Task.detached {
                try? await TastingMenuService.shared.sendCourseAddedNotification(
                    menuId: menuId,
                    menuTheme: menu.theme,
                    addedByUserId: userId,
                    courseType: existingCourse.first?.courseType ?? "Course"
                )
            }
        }
    }

    // MARK: - Publish Menu (#7)

    /// Server-side validated publish — replaces direct DB update.
    func publishMenu(id: String) async throws {
        guard AuthManager.shared.currentUser != nil else {
            throw TastingMenuError.notAuthenticated
        }

        struct PublishResponse: Decodable {
            let success: Bool?
            let error: String?
        }

        let response: PublishResponse = try await supabase.functions.invoke(
            "publish-tasting-menu",
            options: .init(body: ["menuId": id])
        )

        if let error = response.error {
            logger.error("publishMenu — server rejected: \(error)")
            throw TastingMenuError.publishFailed(error)
        }

        logger.info("Published tasting menu \(id)")
    }

    // MARK: - Revoke & Regenerate Invite (#6)

    func revokeAndRegenerateInvite(menuId: String) async throws -> String {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        let response = try await supabase
            .rpc("regenerate_invite_code", params: ["p_menu_id": menuId, "p_user_id": userId])
            .execute()

        // RPC returns a plain text string (the new invite code)
        guard let newCode = String(data: response.data, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !newCode.isEmpty
        else {
            throw TastingMenuError.menuNotFound
        }

        logger.info("Regenerated invite code for menu \(menuId)")
        return newCode
    }

    // MARK: - Update Course Type (#23)

    func updateCourseType(menuId: String, courseOrder: Int, courseType: CourseType) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        let params: [String: AnyJSON] = [
            "p_menu_id": .string(menuId),
            "p_course_order": .integer(courseOrder),
            "p_course_type": .string(courseType.rawValue),
            "p_user_id": .string(userId)
        ]
        try await supabase
            .rpc("update_course_type", params: params)
            .execute()

        logger.info("Updated course \(courseOrder) type to \(courseType.rawValue) in menu \(menuId)")
    }

    // MARK: - Delete

    func deleteMenu(id: String) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            throw TastingMenuError.notAuthenticated
        }

        try await supabase.from("menu_courses").delete().eq("menu_id", value: id).execute()
        try await supabase.from("menu_participants").delete().eq("menu_id", value: id).execute()
        try await supabase.from("tasting_menus").delete().eq("id", value: id).eq("creator_id", value: userId).execute()

        myMenus.removeAll { $0.id == id }
        logger.info("Deleted tasting menu \(id)")
    }

    // MARK: - Fetch Menu Recipes (#9: concurrent downloads)

    func fetchMenuRecipes(menuId: String) async throws -> [String: Recipe] {
        let courses: [MenuCourseDTO] = try await supabase
            .from("menu_courses")
            .select()
            .eq("menu_id", value: menuId)
            .execute()
            .value

        let recipeIds = courses.compactMap(\.recipeId)
        guard !recipeIds.isEmpty else { return [:] }

        let recipes: [SupabaseRecipeDTO] = try await supabase
            .from("recipes")
            .select()
            .in("id", values: recipeIds)
            .execute()
            .value

        var result: [String: Recipe] = [:]

        // #9: Download all images concurrently with TaskGroup
        await withTaskGroup(of: (String, Recipe?).self) { group in
            for dto in recipes {
                guard let remoteId = dto.id else { continue }
                group.addTask {
                    var dishImageData: Data? = nil
                    if let path = dto.dishImagePath {
                        dishImageData = try? await SupabaseManager.shared.client.storage
                            .from("dish-images")
                            .download(path: path)
                    }

                    var inspirationData = Data()
                    if let path = dto.inspirationImagePath {
                        inspirationData = (try? await SupabaseManager.shared.client.storage
                            .from("inspiration-images")
                            .download(path: path)) ?? Data()
                    }

                    let recipe = dto.toRecipe(inspirationData: inspirationData, dishImageData: dishImageData)
                    return (remoteId, recipe)
                }
            }

            for await (remoteId, recipe) in group {
                if let recipe {
                    result[remoteId] = recipe
                }
            }
        }

        logger.info("Fetched \(result.count) menu recipes from Supabase (concurrent)")
        return result
    }

    // MARK: - Send Course Added Notification (#20)

    func sendCourseAddedNotification(
        menuId: String,
        menuTheme: String,
        addedByUserId: String,
        courseType: String
    ) async throws {
        struct NotifyRequest: Encodable {
            let menuId: String
            let menuTheme: String
            let addedByUserId: String
            let courseType: String
        }

        _ = try await supabase.functions.invoke(
            "send-menu-notification",
            options: .init(body: NotifyRequest(
                menuId: menuId,
                menuTheme: menuTheme,
                addedByUserId: addedByUserId,
                courseType: courseType
            ))
        ) as Data

        logger.info("Sent course-added notification for menu \(menuId)")
    }

    // MARK: - Realtime (#4: fix subscription leak)

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

        channels[id] = channel  // Register synchronously before async subscribe

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
    }

    func unsubscribeFromMenu(id: String) {
        // #4: Remove from dict synchronously to prevent duplicate subscriptions on rapid navigation
        guard let channel = channels.removeValue(forKey: id) else { return }
        Task {
            await channel.unsubscribe()
            logger.info("Unsubscribed from realtime for menu \(id)")
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let menuCourseUpdated = Notification.Name("menuCourseUpdated")
    static let openTastingMenuInvite = Notification.Name("openTastingMenuInvite")
}

// MARK: - Errors

enum TastingMenuError: LocalizedError {
    case notAuthenticated
    case menuNotFound
    case menuFull
    case courseAlreadyClaimed
    case publishFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in to participate in tasting menus"
        case .menuNotFound: "Tasting menu not found"
        case .menuFull: "This tasting menu is already full"
        case .courseAlreadyClaimed: "Another chef already added this course — please choose a different one"
        case .publishFailed(let reason): reason
        }
    }
}
