import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Usage")

@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    private static let freeLimit = 5

    /// Server-side usage count, cached locally for offline support
    private var cachedServerCount: Int?

    private init() {
        resetIfNewMonth()
    }

    // MARK: - Guest Usage (local)

    private var guestUsageCount: Int {
        get { UserDefaults.standard.integer(forKey: "guestUsageCount") }
        set { UserDefaults.standard.set(newValue, forKey: "guestUsageCount") }
    }

    private var guestUsageResetDate: Date {
        get {
            let interval = UserDefaults.standard.double(forKey: "guestUsageResetDate")
            if interval == 0 {
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
                let startOfNextMonth = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!)
                UserDefaults.standard.set(startOfNextMonth.timeIntervalSince1970, forKey: "guestUsageResetDate")
                return startOfNextMonth
            }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "guestUsageResetDate")
        }
    }

    // MARK: - Public API

    var isPro: Bool {
        StoreManager.shared.isPro
    }

    var canGenerate: Bool {
        if isPro { return true }
        return remainingGenerations > 0
    }

    var remainingGenerations: Int {
        if isPro { return .max }
        // Use server-side count if authenticated and cached
        if AuthManager.shared.isAuthenticated, let serverCount = cachedServerCount {
            return max(0, Self.freeLimit - serverCount)
        }
        return max(0, Self.freeLimit - guestUsageCount)
    }

    var usageCount: Int {
        if AuthManager.shared.isAuthenticated, let serverCount = cachedServerCount {
            return serverCount
        }
        return guestUsageCount
    }

    var usageLimit: Int {
        Self.freeLimit
    }

    // MARK: - Server Sync

    /// Fetch server-side usage count on app launch (for authenticated users)
    func syncUsageFromServer() async {
        guard AuthManager.shared.isAuthenticated,
              let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            let response = try await SupabaseManager.shared.client
                .rpc("get_usage", params: ["user_id_param": userId])
                .execute()

            struct UsageResponse: Decodable {
                let count: Int
            }

            if let usage = try? JSONDecoder().decode(UsageResponse.self, from: response.data) {
                cachedServerCount = usage.count
                logger.info("Server usage synced: \(usage.count)/\(Self.freeLimit)")
            }
        } catch {
            logger.warning("Failed to sync usage from server: \(error)")
            // Fall back to local count
        }
    }

    func incrementUsage() {
        guestUsageCount += 1
        if let cached = cachedServerCount {
            cachedServerCount = cached + 1
        }
        logger.info("Usage incremented to \(self.usageCount)/\(Self.freeLimit)")

        // Also update remote usage if authenticated (server is authoritative)
        if AuthManager.shared.isAuthenticated {
            Task {
                do {
                    guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
                    try await SupabaseManager.shared.client
                        .rpc("increment_usage", params: ["user_id_param": userId])
                        .execute()
                    logger.info("Remote usage updated successfully")
                } catch {
                    logger.warning("Remote usage update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Reset

    private func resetIfNewMonth() {
        if Date() >= guestUsageResetDate {
            guestUsageCount = 0
            cachedServerCount = nil
            let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            guestUsageResetDate = Calendar.current.startOfDay(for: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: nextMonth))!)
            logger.info("Monthly usage reset")
        }
    }
}
