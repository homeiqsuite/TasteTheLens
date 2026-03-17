import Foundation

enum DeepLink {
    case recipe(UUID)
}

struct DeepLinkHandler {
    static func parse(_ url: URL) -> DeepLink? {
        // Handle tastethelens://recipe/{uuid}
        guard url.scheme == "tastethelens" else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if url.host == "recipe" {
            // tastethelens://recipe/{uuid}
            if let idString = pathComponents.first, let id = UUID(uuidString: idString) {
                return .recipe(id)
            }
            // Also handle tastethelens://recipe?id={uuid}
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let id = UUID(uuidString: idString) {
                return .recipe(id)
            }
        }

        return nil
    }

    /// Generate a shareable URL for a recipe
    static func url(for recipe: Recipe) -> URL? {
        URL(string: "tastethelens://recipe/\(recipe.id.uuidString)")
    }
}
