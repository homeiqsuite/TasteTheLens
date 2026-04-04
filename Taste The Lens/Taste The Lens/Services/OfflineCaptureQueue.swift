import Foundation
import UIKit
import SwiftData
import os

private let logger = makeLogger(category: "OfflineQueue")

struct QueuedCapture: Codable, Identifiable {
    let id: UUID
    let capturedAt: Date
    let chefPersonality: String
    let budgetLimit: Double?
    let courseType: String?
    let isFusion: Bool
    let imageCount: Int  // 1 for single, 2-3 for fusion
}

@Observable @MainActor
final class OfflineCaptureQueue {
    static let shared = OfflineCaptureQueue()

    var queuedCaptures: [QueuedCapture] = []
    var isProcessingQueue = false
    var processingIndex: Int?  // Current item being processed (for UI: "Processing 1 of N")

    var queueCount: Int { queuedCaptures.count }

    private static let maxQueueSize = 10

    private nonisolated var queueDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("offline-queue", isDirectory: true)
    }

    private init() {}

    /// Call from app startup `.task {}` to load persisted queue off the synchronous init path
    func bootstrap() async {
        await Task.detached { [self] in
            let loaded = self.loadQueueFromDisk()
            await MainActor.run {
                self.queuedCaptures = loaded
                if !loaded.isEmpty {
                    logger.info("Loaded \(loaded.count) queued captures from disk")
                }
            }
        }.value
    }

    // MARK: - Enqueue

    func enqueue(image: UIImage, additionalImages: [UIImage]? = nil, budgetLimit: Double? = nil, courseType: String? = nil) -> Bool {
        guard queuedCaptures.count < Self.maxQueueSize else {
            logger.warning("Queue full — cannot enqueue more captures")
            return false
        }

        let id = UUID()
        let itemDir = queueDirectory.appendingPathComponent(id.uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)

            // Save primary image
            guard let imageData = image.jpegDataForUpload(quality: 0.7) else {
                logger.error("Failed to compress image for queue")
                return false
            }
            try imageData.write(to: itemDir.appendingPathComponent("image.jpg"))

            // Save fusion images if present
            let allImages = additionalImages ?? []
            for (index, fusionImage) in allImages.enumerated() {
                if let fusionData = fusionImage.jpegDataForUpload(quality: 0.7) {
                    try fusionData.write(to: itemDir.appendingPathComponent("fusion-\(index).jpg"))
                }
            }

            // Save metadata
            let capture = QueuedCapture(
                id: id,
                capturedAt: Date(),
                chefPersonality: ChefPersonality.current.rawValue,
                budgetLimit: budgetLimit,
                courseType: courseType,
                isFusion: !allImages.isEmpty,
                imageCount: 1 + allImages.count
            )
            let metadataData = try JSONEncoder().encode(capture)
            try metadataData.write(to: itemDir.appendingPathComponent("metadata.json"))

            queuedCaptures.append(capture)
            logger.info("Enqueued capture \(id.uuidString) — queue size: \(self.queuedCaptures.count)")
            return true
        } catch {
            logger.error("Failed to save queued capture: \(error)")
            // Clean up partial writes
            try? FileManager.default.removeItem(at: itemDir)
            return false
        }
    }

    // MARK: - Process Queue

    func processQueue(modelContext: ModelContext) async {
        guard !isProcessingQueue else {
            logger.info("Queue processing already in progress")
            return
        }
        guard !queuedCaptures.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else {
            logger.warning("Cannot process queue — offline")
            return
        }

        isProcessingQueue = true
        logger.info("Processing offline queue — \(self.queuedCaptures.count) items")

        // Process copies to avoid mutation issues during iteration
        let itemsToProcess = queuedCaptures
        for (index, capture) in itemsToProcess.enumerated() {
            guard NetworkMonitor.shared.isConnected else {
                logger.warning("Lost connectivity mid-queue — stopping at item \(index)")
                break
            }
            guard UsageTracker.shared.canGenerate else {
                logger.info("Usage limit reached at item \(index) — stopping queue processing")
                break
            }

            processingIndex = index

            let itemDir = queueDirectory.appendingPathComponent(capture.id.uuidString, isDirectory: true)

            // Load primary image
            guard let imageData = try? Data(contentsOf: itemDir.appendingPathComponent("image.jpg")),
                  let image = UIImage(data: imageData) else {
                logger.error("Failed to load image for queued capture \(capture.id.uuidString) — removing")
                removeItem(capture.id)
                continue
            }

            // Load fusion images if applicable
            var fusionImages: [UIImage] = [image]
            if capture.isFusion {
                for i in 0..<(capture.imageCount - 1) {
                    let fusionURL = itemDir.appendingPathComponent("fusion-\(i).jpg")
                    if let fusionData = try? Data(contentsOf: fusionURL),
                       let fusionImage = UIImage(data: fusionData) {
                        fusionImages.append(fusionImage)
                    }
                }
            }

            // Process through pipeline
            let pipeline = ImageAnalysisPipeline()
            let dishHistory = DishHistory.recent(for: ChefPersonality(rawValue: capture.chefPersonality) ?? .defaultChef)

            if capture.isFusion && fusionImages.count >= 2 {
                await pipeline.processFusion(
                    images: fusionImages,
                    modelContext: modelContext,
                    softAvoiding: dishHistory,
                    budgetLimit: capture.budgetLimit,
                    courseType: capture.courseType
                )
            } else {
                await pipeline.process(
                    image: image,
                    modelContext: modelContext,
                    softAvoiding: dishHistory,
                    budgetLimit: capture.budgetLimit,
                    courseType: capture.courseType
                )
            }

            // Re-check connectivity after pipeline completes (network may have dropped mid-processing)
            guard NetworkMonitor.shared.isConnected || pipeline.state == .complete else {
                logger.warning("Lost connectivity during pipeline processing for \(capture.id.uuidString) — keeping in queue")
                break
            }

            if pipeline.state == .complete, let recipe = pipeline.completedRecipe {
                // Save to SwiftData
                modelContext.insert(recipe)
                do {
                    try modelContext.save()
                    let count = UserDefaults.standard.integer(forKey: "totalRecipeCount")
                    UserDefaults.standard.set(count + 1, forKey: "totalRecipeCount")
                    logger.info("Queued recipe saved: \(recipe.dishName)")

                    if let dishName = pipeline.completedRecipe?.dishName {
                        DishHistory.add(dishName, for: ChefPersonality(rawValue: capture.chefPersonality) ?? .defaultChef)
                    }

                    // Sync to cloud if authenticated
                    if AuthManager.shared.isAuthenticated {
                        await SyncManager.shared.syncRecipe(recipe)
                    }
                } catch {
                    logger.error("Failed to save queued recipe: \(error)")
                }

                removeItem(capture.id)
            } else {
                logger.error("Pipeline failed for queued capture \(capture.id.uuidString) — keeping in queue")
            }
        }

        processingIndex = nil
        isProcessingQueue = false
        logger.info("Queue processing complete — \(self.queuedCaptures.count) items remaining")
    }

    // MARK: - Remove / Clear

    func removeItem(_ id: UUID) {
        let itemDir = queueDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: itemDir)
        queuedCaptures.removeAll { $0.id == id }
        logger.info("Removed queued capture \(id.uuidString) — queue size: \(self.queuedCaptures.count)")
    }

    func clearAll() {
        for capture in queuedCaptures {
            let itemDir = queueDirectory.appendingPathComponent(capture.id.uuidString, isDirectory: true)
            try? FileManager.default.removeItem(at: itemDir)
        }
        queuedCaptures.removeAll()
        logger.info("Queue cleared")
    }

    // MARK: - Persistence

    /// Loads queue from disk. Safe to call from any thread — returns data without mutating state.
    private nonisolated func loadQueueFromDisk() -> [QueuedCapture] {
        let fm = FileManager.default
        let dir = queueDirectory
        guard fm.fileExists(atPath: dir.path) else { return [] }

        do {
            let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            var loaded: [QueuedCapture] = []
            for itemDir in contents {
                let metadataURL = itemDir.appendingPathComponent("metadata.json")
                guard let data = try? Data(contentsOf: metadataURL),
                      let capture = try? JSONDecoder().decode(QueuedCapture.self, from: data) else {
                    // Clean up orphaned directory with corrupted/missing metadata
                    logger.warning("Removing orphaned queue item: \(itemDir.lastPathComponent)")
                    try? fm.removeItem(at: itemDir)
                    continue
                }
                loaded.append(capture)
            }
            return loaded.sorted { $0.capturedAt < $1.capturedAt }
        } catch {
            logger.error("Failed to load queue directory: \(error)")
            return []
        }
    }
}
