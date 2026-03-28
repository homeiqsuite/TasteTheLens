import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "MainViewModel")

// MARK: - Cross-Session Dish History (per-chef, time-decayed)

enum DishHistory {
    private static let storageKey = "dishHistoryV2"
    private static let maxEntriesPerChef = 20
    /// Entries older than this are dropped automatically.
    private static let maxAgeDays: Double = 30

    private struct Entry: Codable {
        let name: String
        let date: Date
    }

    // Internal storage: [chefRawValue: [Entry]]
    private static func loadAll() -> [String: [Entry]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: [Entry]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveAll(_ store: [String: [Entry]]) {
        if let data = try? JSONEncoder().encode(store) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Returns recent dish names for the given chef, pruning expired entries.
    static func recent(for chef: ChefPersonality) -> [String] {
        var store = loadAll()
        let key = chef.rawValue
        let cutoff = Date().addingTimeInterval(-maxAgeDays * 86400)
        // Prune expired
        let entries = (store[key] ?? []).filter { $0.date > cutoff }
        store[key] = entries
        saveAll(store)
        return entries.map(\.name)
    }

    /// Records a dish name for the given chef.
    static func add(_ dishName: String, for chef: ChefPersonality) {
        var store = loadAll()
        let key = chef.rawValue
        let cutoff = Date().addingTimeInterval(-maxAgeDays * 86400)
        var entries = (store[key] ?? []).filter { $0.date > cutoff }
        // Remove duplicates (case-insensitive)
        entries.removeAll { $0.name.caseInsensitiveCompare(dishName) == .orderedSame }
        entries.insert(Entry(name: dishName, date: Date()), at: 0)
        if entries.count > maxEntriesPerChef {
            entries = Array(entries.prefix(maxEntriesPerChef))
        }
        store[key] = entries
        saveAll(store)
    }
}

@Observable @MainActor
final class MainViewModel {
    var currentScreen: AppScreen = .dashboard
    var capturedImage: UIImage?
    var capturedImages: [UIImage]?
    var pipeline = ImageAnalysisPipeline()
    var showSavedRecipes = false
    var showSettings = false
    var showPaywall = false
    var paywallContext: PaywallContext = .outOfGenerations
    var showChallengeFeed = false
    var showTastingMenus = false
    var deepLinkedInviteCode: String?
    var dishHistoryNames: [String] = []
    var hardExcludedDishNames: [String] = []
    var budgetLimit: Double?
    var courseType: String?
    var errorMessage: String?
    var showError = false
    var pendingMenuCourse: (menuId: String, courseOrder: Int)?

    var showPrivacyNotice = false

    private var processingTask: Task<Void, Never>?
    private var lastGenerationStartTime: Date?
    private var pendingCapturedImage: UIImage?
    @ObservationIgnored @AppStorage("hasSeenPrivacyNotice") private var hasSeenPrivacyNotice = false

    // MARK: - Photo Capture

    func handlePhotoCaptured(_ image: UIImage) {
        if !hasSeenPrivacyNotice {
            pendingCapturedImage = image
            showPrivacyNotice = true
            return
        }

        if let last = lastGenerationStartTime, Date().timeIntervalSince(last) < 10 {
            showTemporaryError("Please wait a moment before generating another recipe.")
            return
        }

        if UsageTracker.shared.canGenerate {
            logger.info("Photo received — transitioning to processing. pendingMenuCourse: \(String(describing: self.pendingMenuCourse))")
            capturedImage = image
            dishHistoryNames = DishHistory.recent(for: .current)
            hardExcludedDishNames = []
            courseType = nil
            pipeline = ImageAnalysisPipeline()
            lastGenerationStartTime = Date()
            currentScreen = .processing
        } else {
            logger.info("Usage limit reached — showing paywall")
            paywallContext = .outOfGenerations
            showPaywall = true
        }
    }

    func acceptPrivacyNotice() {
        hasSeenPrivacyNotice = true
        showPrivacyNotice = false
        if let image = pendingCapturedImage {
            pendingCapturedImage = nil
            handlePhotoCaptured(image)
        }
    }

    // MARK: - Fusion Photo Capture

    func handleFusionPhotoCaptured(_ images: [UIImage]) {
        if !hasSeenPrivacyNotice {
            // For fusion, store the first image as pending and show privacy notice
            pendingCapturedImage = images.first
            showPrivacyNotice = true
            return
        }

        if let last = lastGenerationStartTime, Date().timeIntervalSince(last) < 10 {
            showTemporaryError("Please wait a moment before generating another recipe.")
            return
        }

        if UsageTracker.shared.canGenerate {
            logger.info("Fusion photos received (\(images.count) images) — transitioning to processing")
            capturedImages = images
            capturedImage = images.first
            dishHistoryNames = DishHistory.recent(for: .current)
            hardExcludedDishNames = []
            courseType = nil
            pipeline = ImageAnalysisPipeline()
            lastGenerationStartTime = Date()
            currentScreen = .processing
        } else {
            logger.info("Usage limit reached — showing paywall")
            paywallContext = .outOfGenerations
            showPaywall = true
        }
    }

    // MARK: - Processing

    func startProcessing(modelContext: ModelContext, reduceMotion: Bool) {
        guard let image = capturedImage else {
            logger.error("startProcessing called but capturedImage is nil")
            currentScreen = .dashboard
            return
        }

        processingTask = Task {
            logger.info("Processing task started")

            // Only request background execution time if the app actually goes to background
            var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
            let observer = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                guard backgroundTaskID == .invalid else { return }
                backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "RecipeGeneration") {
                    logger.info("Background time expired — cancelling pipeline")
                    self.processingTask?.cancel()
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
                logger.info("App backgrounded — started background task id: \(backgroundTaskID.rawValue)")
            }

            // Ensure observer and background task are always cleaned up, even on cancellation
            defer {
                NotificationCenter.default.removeObserver(observer)
                if backgroundTaskID != .invalid {
                    logger.info("Ending background task — id: \(backgroundTaskID.rawValue)")
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }

            // Route to fusion pipeline if multiple images captured
            if let fusionImages = capturedImages, fusionImages.count >= 2 {
                await pipeline.processFusion(images: fusionImages, modelContext: modelContext, hardExcluding: hardExcludedDishNames, softAvoiding: dishHistoryNames, budgetLimit: budgetLimit, courseType: courseType)
            } else {
                await pipeline.process(image: image, modelContext: modelContext, hardExcluding: hardExcludedDishNames, softAvoiding: dishHistoryNames, budgetLimit: budgetLimit, courseType: courseType)
            }

            logger.info("Pipeline finished — state: \(String(describing: self.pipeline.state))")

            if pipeline.state == .complete {
                if let dishName = pipeline.completedRecipe?.dishName {
                    DishHistory.add(dishName, for: .current)
                }
                logger.info("Pipeline complete — pendingMenuCourse: \(String(describing: self.pendingMenuCourse)), completedRecipe: \(self.pipeline.completedRecipe?.dishName ?? "nil")")

                // If there's a pending menu course, auto-add the recipe to the menu
                if let pending = pendingMenuCourse, let recipe = pipeline.completedRecipe {
                    logger.info("Menu course flow — menuId: \(pending.menuId), courseOrder: \(pending.courseOrder), recipeId: \(recipe.id.uuidString), dishName: \(recipe.dishName)")

                    // Save recipe to SwiftData so it can be displayed in the menu
                    modelContext.insert(recipe)
                    do {
                        try modelContext.save()
                        logger.info("Recipe saved to SwiftData successfully")
                    } catch {
                        logger.error("Failed to save recipe to SwiftData: \(error)")
                    }

                    // Sync recipe to Supabase BEFORE linking to course (foreign key requires it)
                    if AuthManager.shared.isAuthenticated {
                        logger.info("Syncing recipe to Supabase before adding course...")
                        await SyncManager.shared.syncRecipe(recipe)
                        logger.info("Recipe sync complete — remoteId: \(recipe.remoteId ?? "nil")")
                    }

                    // Use the Supabase remote ID (not local SwiftData ID) for the foreign key
                    guard let remoteRecipeId = recipe.remoteId else {
                        logger.error("Recipe has no remoteId after sync — cannot add to menu")
                        pendingMenuCourse = nil
                        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.8)) {
                            currentScreen = .dashboard
                        }
                        showTastingMenus = true
                        return
                    }

                    do {
                        try await TastingMenuService.shared.addCourse(
                            menuId: pending.menuId,
                            courseOrder: pending.courseOrder,
                            recipeId: remoteRecipeId
                        )
                        logger.info("Course added to Supabase successfully")
                        HapticManager.success()
                    } catch {
                        logger.error("Failed to add course to menu: \(error)")
                    }
                    pendingMenuCourse = nil
                    logger.info("Navigating back to dashboard and showing tasting menus sheet")
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.8)) {
                        currentScreen = .dashboard
                    }
                    showTastingMenus = true
                } else {
                    if pendingMenuCourse != nil && pipeline.completedRecipe == nil {
                        logger.error("pendingMenuCourse exists but completedRecipe is nil!")
                    }
                    if pendingMenuCourse == nil {
                        logger.info("No pendingMenuCourse — normal recipe flow")
                    }

                    // Auto-save recipe to SwiftData
                    if let recipe = pipeline.completedRecipe {
                        modelContext.insert(recipe)
                        do {
                            try modelContext.save()
                            logger.info("Recipe auto-saved to SwiftData")
                        } catch {
                            logger.error("Failed to auto-save recipe: \(error)")
                        }

                        if AuthManager.shared.isAuthenticated {
                            await SyncManager.shared.syncRecipe(recipe)
                        }
                    }

                    logger.info("Transitioning to recipe card")
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.8)) {
                        currentScreen = .recipeCard
                    }
                }
            } else if case .rejected(let reason) = pipeline.state {
                logger.info("Image rejected — \(reason)")
                showTemporaryError(reason)
            } else if case .failed(let message) = pipeline.state {
                logger.error("Pipeline failed — showing error: \(message)")
                showTemporaryError(message)
            }

        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        pipeline = ImageAnalysisPipeline()
        pendingMenuCourse = nil
        capturedImages = nil
        currentScreen = .camera
        logger.info("Processing cancelled by user")
    }

    // MARK: - Reimagine

    func handleReimaginNotification(_ notification: Notification) {
        if let showPaywallFlag = notification.userInfo?["showPaywall"] as? Bool, showPaywallFlag {
            let contextRaw = notification.userInfo?["paywallContext"] as? String
            paywallContext = contextRaw == "reimagination" ? .featureGated(.reimagination) : .outOfGenerations
            showPaywall = true
            return
        }

        guard let dishName = notification.userInfo?["excludeDishName"] as? String,
              let imageData = notification.userInfo?["inspirationImageData"] as? Data,
              let image = UIImage(data: imageData) else { return }

        // Hard-exclude the current dish + any previously hard-excluded dishes
        if !hardExcludedDishNames.contains(where: { $0.caseInsensitiveCompare(dishName) == .orderedSame }) {
            hardExcludedDishNames.append(dishName)
        }
        // Refresh history for the current chef (dish was already added on completion)
        dishHistoryNames = DishHistory.recent(for: .current)
        capturedImage = image
        courseType = notification.userInfo?["courseType"] as? String
        if let budget = notification.userInfo?["budgetLimit"] as? Double {
            budgetLimit = budget
        }
        pipeline = ImageAnalysisPipeline()
        lastGenerationStartTime = Date()
        currentScreen = .processing
    }

    // MARK: - Navigation

    func navigateToCamera() {
        currentScreen = .camera
    }

    func handleAddMenuCourse(_ notification: Notification) {
        guard let menuId = notification.userInfo?["menuId"] as? String,
              let courseOrder = notification.userInfo?["courseOrder"] as? Int else {
            logger.error("handleAddMenuCourse — missing menuId or courseOrder in notification")
            return
        }
        logger.info("handleAddMenuCourse — menuId: \(menuId), courseOrder: \(courseOrder)")
        pendingMenuCourse = (menuId: menuId, courseOrder: courseOrder)
        // Dismiss tasting menus sheet and navigate to camera
        showTastingMenus = false
        currentScreen = .camera
        logger.info("handleAddMenuCourse — pendingMenuCourse set, navigating to camera")
    }

    func resetToDashboard() {
        processingTask?.cancel()
        processingTask = nil
        currentScreen = .dashboard
        capturedImage = nil
        capturedImages = nil
        dishHistoryNames = []
        hardExcludedDishNames = []
        budgetLimit = nil
        courseType = nil
        lastGenerationStartTime = nil
        pipeline = ImageAnalysisPipeline()
    }

    // MARK: - Private

    private var errorDismissTask: Task<Void, Never>?

    private func showTemporaryError(_ message: String) {
        errorDismissTask?.cancel()
        errorMessage = message
        showError = true
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { showError = false }
            currentScreen = .dashboard
        }
    }
}
