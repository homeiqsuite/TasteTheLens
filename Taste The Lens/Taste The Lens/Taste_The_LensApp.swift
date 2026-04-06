import SwiftUI
import SwiftData
import os

private let deepLinkLogger = makeLogger(category: "DeepLink")

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
                    await OfflineCaptureQueue.shared.bootstrap()
                    RemoteConfigManager.shared.startPeriodicSync()
                    await AuthManager.shared.restoreSession()
                    // On authenticated launch, claim any unowned local recipes and sync
                    if AuthManager.shared.isAuthenticated {
                        // Check for legacy subscriptions
                        await StoreManager.shared.checkLegacySubscription()
                        // One-time credit reconciliation (MAX of server vs client)
                        await UsageTracker.shared.reconcileCreditsIfNeeded()
                        // Claim welcome credits for new users (idempotent)
                        await UsageTracker.shared.claimWelcomeCreditsIfNeeded()
                        // Sync server-side usage and credits
                        await UsageTracker.shared.syncUsageFromServer()
                        await UsageTracker.shared.syncCreditsFromServer()
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
                        // Re-sync subscription status and credits whenever the app
                        // returns to the foreground (covers background → foreground
                        // transitions that the one-time .task doesn't handle).
                        if AuthManager.shared.isAuthenticated {
                            Task {
                                await UsageTracker.shared.syncCreditsFromServer()
                            }
                        }
                    }
                }
                .onOpenURL { url in
                    deepLinkLogger.info("Received URL: \(url.absoluteString)")
                    if let deepLink = DeepLinkHandler.parse(url) {
                        switch deepLink {
                        case .recipe(let id):
                            deepLinkLogger.info("Parsed as recipe — remoteId=\(id)")
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
    case deepLinkedRecipe(String)
    case resetPassword(URL)

    var id: String {
        switch self {
        case .deepLinkedRecipe(let remoteId): return "recipe-\(remoteId)"
        case .resetPassword(let url): return "reset-\(url.absoluteString)"
        }
    }
}

/// Looks up a recipe by remoteId — checks local library first, then fetches from server.
struct DeepLinkedRecipeView: View {
    let recipeID: String
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]
    @State private var fetchedRecipe: Recipe?
    @State private var isLoading = false
    @State private var fetchFailed = false

    private var recipe: Recipe? {
        fetchedRecipe ?? recipes.first { $0.remoteId == recipeID }
    }

    var body: some View {
        NavigationStack {
            if let recipe {
                RecipeCardView(recipe: recipe)
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.gold)
                    Text("Loading recipe...")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.darkBg)
            } else if fetchFailed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.darkTextHint)
                    Text("Recipe not available")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)
                    Text("This recipe may have been removed or isn't publicly accessible.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.darkBg)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.darkBg)
            }
        }
        .task { await fetchFromServer() }
    }

    private func fetchFromServer() async {
        if let local = recipes.first(where: { $0.remoteId == recipeID }) {
            deepLinkLogger.info("DeepLink: found recipe locally — \"\(local.dishName)\"")
            return
        }
        guard !isLoading else { return }
        deepLinkLogger.info("DeepLink: not in local library, fetching from server — remoteId=\(recipeID)")
        isLoading = true

        do {
            let remote = try await SyncManager.shared.fetchRecipe(remoteId: recipeID)
            fetchedRecipe = remote
            deepLinkLogger.info("DeepLink: fetch succeeded — showing \"\(remote.dishName)\"")
        } catch {
            deepLinkLogger.error("DeepLink: fetch failed — \(error)")
            fetchFailed = true
        }

        isLoading = false
    }
}
