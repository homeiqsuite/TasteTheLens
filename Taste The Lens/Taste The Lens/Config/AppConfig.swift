import Foundation
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "AppConfig")

enum AppConfig {
    static var supabaseURL: String {
        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"], !url.isEmpty {
            return url
        }
        if let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !url.isEmpty {
            return url
        }
        logger.error("SUPABASE_URL not set. Add it to Secrets.xcconfig or scheme environment variables.")
        return ""
    }

    static var supabaseAnonKey: String {
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty {
            return key
        }
        logger.error("SUPABASE_ANON_KEY not set. Add it to Secrets.xcconfig or scheme environment variables.")
        return ""
    }

    /// Returns true if the minimum required configuration is present.
    static var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
}
