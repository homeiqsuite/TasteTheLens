import Foundation

enum DeepLink {
    /// Shared recipe, identified by its secret share token (not the row id).
    case recipe(String)
    /// Shared meal plan, identified by its secret share token (not the row id).
    case mealPlan(String)
    /// A single shared meal: the parent plan's share token + the meal's row id.
    case meal(planToken: String, mealId: String)
    case challenge(String)
    case tastingMenu(String)
    case resetCallback(String)
}

struct DeepLinkHandler {
    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "tastethelens" else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // tastethelens://recipe/{shareToken}
        if url.host == "recipe" {
            if let token = pathComponents.first, UUID(uuidString: token) != nil {
                return .recipe(token)
            }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
               UUID(uuidString: token) != nil {
                return .recipe(token)
            }
        }

        // tastethelens://mealplan/{shareToken}
        if url.host == "mealplan" {
            if let token = pathComponents.first, UUID(uuidString: token) != nil {
                return .mealPlan(token)
            }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
               UUID(uuidString: token) != nil {
                return .mealPlan(token)
            }
        }

        // tastethelens://meal/{planShareToken}/{mealId}
        if url.host == "meal", pathComponents.count >= 2 {
            let planToken = pathComponents[0]
            let mealId = pathComponents[1]
            if UUID(uuidString: planToken) != nil, UUID(uuidString: mealId) != nil {
                return .meal(planToken: planToken, mealId: mealId)
            }
        }

        // tastethelens://challenge/{uuid}
        if url.host == "challenge" {
            if let idString = pathComponents.first,
               UUID(uuidString: idString) != nil {
                return .challenge(idString)
            }
        }

        // tastethelens://menu/{inviteCode}
        if url.host == "menu" {
            if let code = pathComponents.first,
               !code.isEmpty,
               code.count <= 64,
               code.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil {
                return .tastingMenu(code)
            }
        }

        // tastethelens://reset-callback?code={code}
        if url.host == "reset-callback" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
               !code.isEmpty,
               code.count <= 512 {
                return .resetCallback(code)
            }
        }

        return nil
    }

    /// Generate a shareable URL for a challenge
    static func url(forChallenge id: String) -> URL? {
        URL(string: "tastethelens://challenge/\(id)")
    }

    /// Generate a shareable URL for a tasting menu invite
    static func url(forMenuInvite code: String) -> URL? {
        URL(string: "tastethelens://menu/\(code)")
    }

    // MARK: - Token-based share links
    //
    // Share links carry a per-item secret `share_token` (minted server-side via
    // `SyncManager.shareLink…`), NOT the row id. Only the holder of the token can
    // resolve the item; the row id is never bulk-enumerable. See SyncManager.

    static func recipeURL(token: String) -> URL? {
        URL(string: "tastethelens://recipe/\(token)")
    }

    static func mealPlanURL(token: String) -> URL? {
        URL(string: "tastethelens://mealplan/\(token)")
    }

    static func mealURL(planToken: String, mealId: String) -> URL? {
        URL(string: "tastethelens://meal/\(planToken)/\(mealId)")
    }
}
