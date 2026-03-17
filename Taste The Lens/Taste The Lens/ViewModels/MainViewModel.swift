import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "MainViewModel")

@Observable @MainActor
final class MainViewModel {
    var currentScreen: AppScreen = .camera
    var capturedImage: UIImage?
    var pipeline = ImageAnalysisPipeline()
    var showSavedRecipes = false
    var showSettings = false
    var showPaywall = false
    var excludedDishNames: [String] = []
    var errorMessage: String?
    var showError = false

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
            currentScreen = .camera
            return
        }

        processingTask = Task {
            logger.info("Processing task started")
            await pipeline.process(image: image, modelContext: modelContext, excluding: excludedDishNames)

            logger.info("Pipeline finished — state: \(String(describing: self.pipeline.state))")

            if pipeline.state == .complete {
                logger.info("Transitioning to recipe card")
                withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.8)) {
                    currentScreen = .recipeCard
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

    func resetToCamera() {
        processingTask?.cancel()
        processingTask = nil
        currentScreen = .camera
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
            currentScreen = .camera
        }
    }
}
