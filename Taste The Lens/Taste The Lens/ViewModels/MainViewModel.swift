import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "MainViewModel")

@Observable @MainActor
final class MainViewModel {
    var currentScreen: AppScreen = .dashboard
    var capturedImage: UIImage?
    var pipeline = ImageAnalysisPipeline()
    var showSavedRecipes = false
    var showSettings = false
    var showPaywall = false
    var showChallengeFeed = false
    var showTastingMenus = false
    var excludedDishNames: [String] = []
    var errorMessage: String?
    var showError = false
    var pendingMenuCourse: (menuId: String, courseOrder: Int)?

    private var processingTask: Task<Void, Never>?

    // MARK: - Photo Capture

    func handlePhotoCaptured(_ image: UIImage) {
        if UsageTracker.shared.canGenerate {
            logger.info("Photo received — transitioning to processing")
            capturedImage = image
            excludedDishNames = []
            pipeline = ImageAnalysisPipeline()
            currentScreen = .processing
        } else {
            logger.info("Usage limit reached — showing paywall")
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
            await pipeline.process(image: image, modelContext: modelContext, excluding: excludedDishNames)

            logger.info("Pipeline finished — state: \(String(describing: self.pipeline.state))")

            if pipeline.state == .complete {
                // If there's a pending menu course, auto-add the recipe to the menu
                if let pending = pendingMenuCourse, let recipe = pipeline.completedRecipe {
                    logger.info("Adding recipe to menu \(pending.menuId) course \(pending.courseOrder)")
                    do {
                        try await TastingMenuService.shared.addCourse(
                            menuId: pending.menuId,
                            courseOrder: pending.courseOrder,
                            recipeId: recipe.id.uuidString
                        )
                        HapticManager.success()
                    } catch {
                        logger.error("Failed to add course to menu: \(error)")
                    }
                    pendingMenuCourse = nil
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.8)) {
                        currentScreen = .dashboard
                    }
                    showTastingMenus = true
                } else {
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
        currentScreen = .camera
        logger.info("Processing cancelled by user")
    }

    // MARK: - Reimagine

    func handleReimaginNotification(_ notification: Notification) {
        if let showPaywallFlag = notification.userInfo?["showPaywall"] as? Bool, showPaywallFlag {
            showPaywall = true
            return
        }

        guard let dishName = notification.userInfo?["excludeDishName"] as? String,
              let imageData = notification.userInfo?["inspirationImageData"] as? Data,
              let image = UIImage(data: imageData) else { return }

        excludedDishNames.append(dishName)
        capturedImage = image
        pipeline = ImageAnalysisPipeline()
        currentScreen = .processing
    }

    // MARK: - Navigation

    func navigateToCamera() {
        currentScreen = .camera
    }

    func handleAddMenuCourse(_ notification: Notification) {
        guard let menuId = notification.userInfo?["menuId"] as? String,
              let courseOrder = notification.userInfo?["courseOrder"] as? Int else { return }
        pendingMenuCourse = (menuId: menuId, courseOrder: courseOrder)
        // Dismiss tasting menus sheet and navigate to camera
        showTastingMenus = false
        currentScreen = .camera
    }

    func resetToDashboard() {
        processingTask?.cancel()
        processingTask = nil
        currentScreen = .dashboard
        capturedImage = nil
        excludedDishNames = []
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
