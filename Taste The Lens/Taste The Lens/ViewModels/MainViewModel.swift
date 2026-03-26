import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "MainViewModel")

@Observable @MainActor
final class MainViewModel {
    var currentScreen: AppScreen = .dashboard
    var capturedImage: UIImage?
    var pipeline = ImageAnalysisPipeline()
    var showSavedRecipes = false
    var showSettings = false
    var showPaywall = false
    var paywallContext: PaywallContext = .outOfGenerations
    var showChallengeFeed = false
    var showTastingMenus = false
    var deepLinkedInviteCode: String?
    var excludedDishNames: [String] = []
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
            excludedDishNames = []
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

            await pipeline.process(image: image, modelContext: modelContext, excluding: excludedDishNames, budgetLimit: budgetLimit, courseType: courseType)

            logger.info("Pipeline finished — state: \(String(describing: self.pipeline.state))")

            if pipeline.state == .complete {
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

            // Clean up background task observer and end any active background task
            NotificationCenter.default.removeObserver(observer)
            if backgroundTaskID != .invalid {
                logger.info("Ending background task — id: \(backgroundTaskID.rawValue)")
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        pipeline = ImageAnalysisPipeline()
        pendingMenuCourse = nil
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

        excludedDishNames.append(dishName)
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
        excludedDishNames = []
        budgetLimit = nil
        courseType = nil
        lastGenerationStartTime = nil
        pipeline = ImageAnalysisPipeline()
    }

    // MARK: - Private

    private func showTemporaryError(_ message: String) {
        errorMessage = message
        showError = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { showError = false }
            currentScreen = .dashboard
        }
    }
}
