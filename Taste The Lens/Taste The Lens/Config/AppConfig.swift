import Foundation

enum AppConfig {
    static var anthropicAPIKey: String {
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        fatalError("ANTHROPIC_API_KEY not set. Add it to Secrets.xcconfig or scheme environment variables.")
    }

    static var geminiAPIKey: String {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        fatalError("GEMINI_API_KEY not set. Add it to Secrets.xcconfig or scheme environment variables.")
    }

    static var falAPIKey: String {
        if let key = ProcessInfo.processInfo.environment["FAL_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.infoDictionary?["FAL_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        fatalError("FAL_API_KEY not set. Add it to Secrets.xcconfig or scheme environment variables.")
    }
}
