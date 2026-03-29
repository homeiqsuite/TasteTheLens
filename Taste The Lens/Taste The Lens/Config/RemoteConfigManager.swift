import Foundation
import Supabase
import os

private let logger = makeLogger(category: "RemoteConfig")

@Observable @MainActor
final class RemoteConfigManager {
    static let shared = RemoteConfigManager()

    private var config: [String: Any] = [:]
    private var refreshTask: Task<Void, Never>?
    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private static let cacheKey = "remote_config_cache"

    private init() {
        loadFromCache()
    }

    // MARK: - Lifecycle

    /// Begin periodic sync. Call once at app launch.
    func startPeriodicSync() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetch()
                let interval = self?.int(for: "sync_interval_seconds", default: 300) ?? 300
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Fetch latest config from Supabase. Safe to call anytime (e.g. foreground resume).
    func fetch() async {
        do {
            let rows: [ConfigRow] = try await supabase
                .from("remote_config")
                .select("key, value")
                .execute()
                .value

            var newConfig: [String: Any] = [:]
            for row in rows {
                newConfig[row.key] = row.value.underlyingValue
            }
            config = newConfig
            saveToCache(rows)
            logger.info("Remote config fetched — \(rows.count) keys")
        } catch {
            logger.error("Remote config fetch failed: \(error.localizedDescription)")
            // Keep using cached/default values
        }
    }

    // MARK: - Typed Accessors

    func bool(for key: String, default fallback: Bool = false) -> Bool {
        if let value = config[key] as? Bool { return value }
        if let value = config[key] as? String { return value == "true" }
        return fallback
    }

    func int(for key: String, default fallback: Int = 0) -> Int {
        if let value = config[key] as? Int { return value }
        if let value = config[key] as? Double { return Int(value) }
        if let value = config[key] as? String, let parsed = Int(value) { return parsed }
        return fallback
    }

    func string(for key: String, default fallback: String = "") -> String {
        if let value = config[key] as? String { return value }
        return fallback
    }

    func stringArray(for key: String, default fallback: [String] = []) -> [String] {
        if let value = config[key] as? [String] { return value }
        return fallback
    }

    // MARK: - Convenience Properties

    var maintenanceMode: Bool { bool(for: "maintenance_mode") }
    var maintenanceMessage: String { string(for: "maintenance_message", default: "We're upgrading TasteTheLens. Back shortly!") }
    var gauntletEnabled: Bool { bool(for: "gauntlet_enabled", default: true) }
    var tastingMenusEnabled: Bool { bool(for: "tasting_menus_enabled", default: true) }
    var fusionModeEnabled: Bool { bool(for: "fusion_mode_enabled", default: true) }
    var pushNotificationsEnabled: Bool { bool(for: "push_notifications_enabled", default: true) }
    var communityImpactEnabled: Bool { bool(for: "community_impact_enabled", default: true) }
    var challengeDurationHours: Int { int(for: "challenge_duration_hours", default: 72) }
    var freeGenerationLimit: Int { int(for: "free_generation_limit", default: 5) }
    var defaultImageGenModel: String { string(for: "default_image_gen_model", default: "imagen4") }
    var availableImageGenModels: [String] { stringArray(for: "available_image_gen_models", default: ["imagen4", "imagen4fast", "fluxPro", "fluxSchnell"]) }
    var recipeGenProvider: String { string(for: "recipe_gen_provider", default: "gemini") }
    var minAppVersion: String { string(for: "min_app_version", default: "1.0.0") }
    var maxFusionImages: Int { int(for: "max_fusion_images", default: 3) }

    // MARK: - Cache (UserDefaults)

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let rows = try? JSONDecoder().decode([ConfigRow].self, from: data) else {
            return
        }
        for row in rows {
            config[row.key] = row.value.underlyingValue
        }
        logger.info("Remote config loaded from cache — \(rows.count) keys")
    }

    private func saveToCache(_ rows: [ConfigRow]) {
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }
}

// MARK: - DTO

/// Represents a single row from the remote_config table.
private struct ConfigRow: Codable {
    let key: String
    let value: AnyJSONValue
}

/// A type-erased JSON value that can decode any JSONB cell.
private enum AnyJSONValue: Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyJSONValue])
    case null

    var underlyingValue: Any {
        switch self {
        case .bool(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map { $0.underlyingValue }
        case .null: return NSNull()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([AnyJSONValue].self) {
            self = .array(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
