import SwiftUI
import SwiftData

@main
struct Taste_The_LensApp: App {
    @State private var deepLinkedRecipeID: UUID?
    @State private var showDeepLinkedRecipe = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .task {
                    await AuthManager.shared.restoreSession()
                    // On authenticated launch, claim any unowned local recipes and sync
                    if AuthManager.shared.isAuthenticated {
                        // Sync server-side usage limits
                        await UsageTracker.shared.syncUsageFromServer()
                        // Claim any unowned local recipes and sync
                        if let container = try? ModelContainer(for: Recipe.self) {
                            let context = ModelContext(container)
                            await SyncManager.shared.claimLocalRecipes(modelContext: context)
                        }
                    }
                }
                .onOpenURL { url in
                    if let deepLink = DeepLinkHandler.parse(url) {
                        switch deepLink {
                        case .recipe(let id):
                            deepLinkedRecipeID = id
                            showDeepLinkedRecipe = true
                        }
                    }
                }
                .sheet(isPresented: $showDeepLinkedRecipe) {
                    if let recipeID = deepLinkedRecipeID {
                        DeepLinkedRecipeView(recipeID: recipeID)
                    }
                }
        }
        .modelContainer(for: Recipe.self)
    }
}

/// Looks up a recipe by ID from SwiftData and displays it
struct DeepLinkedRecipeView: View {
    let recipeID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]

    private var recipe: Recipe? {
        recipes.first { $0.id == recipeID }
    }

    var body: some View {
        NavigationStack {
            if let recipe {
                RecipeCardView(recipe: recipe)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Recipe not found")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.051, green: 0.051, blue: 0.059))
            }
        }
    }
}
