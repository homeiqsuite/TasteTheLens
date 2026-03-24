import SwiftUI
import SwiftData

@main
struct Taste_The_LensApp: App {
    @State private var deepLinkedRecipeID: UUID?
    @State private var showDeepLinkedRecipe = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await AuthManager.shared.restoreSession()
                    // On authenticated launch, claim any unowned local recipes and sync
                    if AuthManager.shared.isAuthenticated {
                        // Re-check subscription status now that auth is ready
                        await StoreManager.shared.updateSubscriptionStatus()
                        // Sync server-side usage and credits
                        await UsageTracker.shared.syncUsageFromServer()
                        await UsageTracker.shared.syncCreditsFromServer()
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
                        case .challenge:
                            // Handled via ChallengeFeedView
                            break
                        case .tastingMenu(let code):
                            NotificationCenter.default.post(
                                name: .openTastingMenuInvite,
                                object: nil,
                                userInfo: ["inviteCode": code]
                            )
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
                        .foregroundStyle(Theme.darkTextHint)
                    Text("Recipe not found")
                        .foregroundStyle(Theme.darkTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.darkBg)
            }
        }
    }
}
