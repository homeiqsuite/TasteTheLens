import SwiftUI
import SwiftData

@main
struct Taste_The_LensApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSheet: AppSheet?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Start network monitoring and load offline queue early
                    _ = NetworkMonitor.shared
                    _ = OfflineCaptureQueue.shared
                    RemoteConfigManager.shared.startPeriodicSync()
                    await AuthManager.shared.restoreSession()
                    // On authenticated launch, claim any unowned local recipes and sync
                    if AuthManager.shared.isAuthenticated {
                        // Re-check subscription status now that auth is ready
                        await StoreManager.shared.updateSubscriptionStatus()
                        // One-time credit reconciliation (MAX of server vs client)
                        await UsageTracker.shared.reconcileCreditsIfNeeded()
                        // Sync server-side usage and credits
                        await UsageTracker.shared.syncUsageFromServer()
                        await UsageTracker.shared.syncCreditsFromServer()
                        // Schedule credit expiry notification if subscriber has credits
                        CreditExpiryNotificationService.shared.scheduleExpiryNotificationIfNeeded()
                        // Claim any unowned local recipes and sync
                        if let container = try? ModelContainer(for: Recipe.self) {
                            let context = ModelContext(container)
                            await SyncManager.shared.claimLocalRecipes(modelContext: context)
                            await SyncManager.shared.syncAll(modelContext: context)
                        }
                        // Request push notification permission and register token
                        if RemoteConfigManager.shared.pushNotificationsEnabled {
                            await PushNotificationService.shared.requestPermission()
                            await PushNotificationService.shared.loadPreferences()
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await RemoteConfigManager.shared.fetch() }
                    }
                }
                .onOpenURL { url in
                    if let deepLink = DeepLinkHandler.parse(url) {
                        switch deepLink {
                        case .recipe(let id):
                            activeSheet = .deepLinkedRecipe(id)
                        case .challenge:
                            // Handled via ChallengeFeedView
                            break
                        case .tastingMenu(let code):
                            NotificationCenter.default.post(
                                name: .openTastingMenuInvite,
                                object: nil,
                                userInfo: ["inviteCode": code]
                            )
                        case .resetCallback:
                            activeSheet = .resetPassword(url)
                        }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .deepLinkedRecipe(let id):
                        DeepLinkedRecipeView(recipeID: id)
                    case .resetPassword(let url):
                        ResetPasswordView(callbackURL: url)
                    }
                }
        }
        .modelContainer(for: Recipe.self)
    }
}

// MARK: - App-Level Sheet

enum AppSheet: Identifiable {
    case deepLinkedRecipe(UUID)
    case resetPassword(URL)

    var id: String {
        switch self {
        case .deepLinkedRecipe(let uuid): return "recipe-\(uuid)"
        case .resetPassword(let url): return "reset-\(url.absoluteString)"
        }
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
