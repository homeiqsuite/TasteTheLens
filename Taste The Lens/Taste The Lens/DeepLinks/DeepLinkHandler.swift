import Foundation

enum DeepLink {
    case recipe(String)
    case challenge(String)
    case tastingMenu(String)
    case resetCallback(String)
}

struct DeepLinkHandler {
    static func parse(_ url: URL) -> DeepLink? {
        // Handle tastethelens://recipe/{uuid}
        guard url.scheme == "tastethelens" else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if url.host == "recipe" {
            // tastethelens://recipe/{remoteId}
            if let idString = pathComponents.first, !idString.isEmpty {
                return .recipe(idString)
            }
            // Also handle tastethelens://recipe?id={remoteId}
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               !idString.isEmpty {
                return .recipe(idString)
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

    /// Generate a shareable URL for a recipe (requires remoteId — recipe must be synced first)
    static func url(for recipe: Recipe) -> URL? {
        guard let remoteId = recipe.remoteId else { return nil }
        return URL(string: "tastethelens://recipe/\(remoteId)")
    }
}
