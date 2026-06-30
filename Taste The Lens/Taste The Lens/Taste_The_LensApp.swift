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
                        // Claim any unowned local recipes and sync.
                        // Use the SHARED container (never a second ad-hoc one) so
                        // the on-disk store is only ever opened with one schema.
                        let context = ModelContext(AppModelContainer.shared)
                        await SyncManager.shared.claimLocalRecipes(modelContext: context)
                        await SyncManager.shared.syncAll(modelContext: context)
                        // Request push notification permission and register token
                        if RemoteConfigManager.shared.pushNotificationsEnabled {
                            await PushNotificationService.shared.requestPermission()
                            await PushNotificationService.shared.loadPreferences()
                        }
                    }
                    // Schedule the daily "come back and cook" local reminder.
                    // No auth required — fires once notification permission is granted.
                    await DailyReminderService.shared.refresh()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await RemoteConfigManager.shared.fetch() }
                        // Re-extend the rolling reminder window on each foreground.
                        Task { await DailyReminderService.shared.refresh() }
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
                    // Don't log the full URL — for share links the path is the secret token.
                    deepLinkLogger.info("Received deep link: \(url.host ?? "?", privacy: .public)")
                    if let deepLink = DeepLinkHandler.parse(url) {
                        switch deepLink {
                        case .recipe(let token):
                            deepLinkLogger.info("Parsed as shared recipe")
                            activeSheet = .deepLinkedRecipe(token)
                        case .mealPlan(let token):
                            deepLinkLogger.info("Parsed as shared meal plan")
                            activeSheet = .deepLinkedMealPlan(token)
                        case .meal(let planToken, let mealId):
                            deepLinkLogger.info("Parsed as shared meal")
                            activeSheet = .deepLinkedMeal(planToken: planToken, mealId: mealId)
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
                    case .deepLinkedMealPlan(let id):
                        DeepLinkedMealPlanView(planID: id)
                    case .deepLinkedMeal(let planToken, let mealId):
                        DeepLinkedMealView(planToken: planToken, mealId: mealId)
                    case .resetPassword(let url):
                        ResetPasswordView(callbackURL: url)
                    }
                }
        }
        .modelContainer(AppModelContainer.shared)
    }
}

// MARK: - App-Level Sheet

enum AppSheet: Identifiable {
    case deepLinkedRecipe(String)
    case deepLinkedMealPlan(String)
    case deepLinkedMeal(planToken: String, mealId: String)
    case resetPassword(URL)

    var id: String {
        switch self {
        case .deepLinkedRecipe(let token): return "recipe-\(token)"
        case .deepLinkedMealPlan(let token): return "mealplan-\(token)"
        case .deepLinkedMeal(_, let mealId): return "meal-\(mealId)"
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
            let remote = try await SyncManager.shared.fetchRecipe(shareToken: recipeID)
            fetchedRecipe = remote
            deepLinkLogger.info("DeepLink: fetch succeeded — showing \"\(remote.dishName)\"")
        } catch {
            deepLinkLogger.error("DeepLink: fetch failed — \(error)")
            fetchFailed = true
        }

        isLoading = false
    }
}

/// Opens a shared meal plan by remoteId — local library first, then server.
struct DeepLinkedMealPlanView: View {
    let planID: String
    @Query private var plans: [MealPlan]
    @State private var fetchedPlan: MealPlan?
    @State private var isLoading = false
    @State private var fetchFailed = false

    private var plan: MealPlan? {
        fetchedPlan ?? plans.first { $0.remoteId == planID }
    }

    var body: some View {
        NavigationStack {
            if let plan {
                MealPlanView(plan: plan)
            } else if fetchFailed {
                DeepLinkUnavailableView(message: "This meal plan may have been removed or isn't publicly accessible.")
            } else {
                DeepLinkLoadingView(label: "Loading meal plan…")
            }
        }
        .task { await load() }
    }

    private func load() async {
        if plans.contains(where: { $0.remoteId == planID }) { return }
        guard !isLoading else { return }
        isLoading = true
        do { fetchedPlan = try await SyncManager.shared.fetchMealPlan(shareToken: planID) }
        catch { fetchFailed = true }
        isLoading = false
    }
}

/// Opens a single shared meal by remoteId.
struct DeepLinkedMealView: View {
    let planToken: String
    let mealId: String
    @State private var fetchedMeal: PlannedMeal?
    @State private var isLoading = false
    @State private var fetchFailed = false

    var body: some View {
        NavigationStack {
            if let meal = fetchedMeal {
                MealDetailView(meal: meal)
            } else if fetchFailed {
                DeepLinkUnavailableView(message: "This meal may have been removed or isn't publicly accessible.")
            } else {
                DeepLinkLoadingView(label: "Loading meal…")
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        do { fetchedMeal = try await SyncManager.shared.fetchMeal(planToken: planToken, mealId: mealId) }
        catch { fetchFailed = true }
        isLoading = false
    }
}

private struct DeepLinkLoadingView: View {
    let label: String
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(Theme.gold)
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.darkTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.darkBg)
    }
}

private struct DeepLinkUnavailableView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Theme.darkTextHint)
            Text("Not available")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.darkTextPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.darkBg)
    }
}
