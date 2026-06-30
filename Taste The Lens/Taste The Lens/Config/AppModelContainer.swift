import SwiftData
import Foundation
import os

private let logger = makeLogger(category: "ModelContainer")

/// Single source of truth for the app's SwiftData container.
///
/// Every part of the app (the `.modelContainer` view modifier, background sync,
/// etc.) MUST use this one shared container. Creating ad-hoc `ModelContainer(for:)`
/// instances with different schemas against the same on-disk `default.store`
/// causes schema conflicts and corruption — the "no such table: ZMEALPLAN" /
/// "I/O error" / "bind on a busy prepared statement" class of errors.
enum AppModelContainer {
    /// All persisted model types. `PlannedMeal` is reachable from `MealPlan` via
    /// its relationship (so SwiftData includes it automatically), but the schema
    /// is driven by the top-level aggregates listed here.
    static let schema = Schema([Recipe.self, MealPlan.self])

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Last-resort recovery: the on-disk store is incompatible or corrupt.
            // Recipes and meal plans are server-synced, so the local store is a
            // cache we can safely rebuild rather than crash-looping on launch.
            logger.error("Store open failed (\(error.localizedDescription)). Resetting local store and retrying.")
            Self.destroyStore(for: configuration)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Unrecoverable SwiftData store error: \(error)")
            }
        }
    }()

    /// Deletes the SQLite store and its WAL/SHM sidecar files.
    private static func destroyStore(for configuration: ModelConfiguration) {
        let storeURL = configuration.url
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? fileManager.removeItem(at: url)
        }
    }
}
