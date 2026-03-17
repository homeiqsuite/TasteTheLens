import Foundation
import Supabase
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Supabase")

@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        guard let url = URL(string: AppConfig.supabaseURL) else {
            fatalError("Invalid SUPABASE_URL: \(AppConfig.supabaseURL)")
        }
        let key = AppConfig.supabaseAnonKey

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )

        logger.info("Supabase client initialized — \(AppConfig.supabaseURL)")
    }
}
