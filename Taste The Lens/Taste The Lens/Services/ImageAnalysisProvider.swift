import UIKit

// MARK: - Protocol

protocol ImageAnalysisProvider: Sendable {
    func analyzeImage(_ image: UIImage, systemPrompt: String) async throws -> (ClaudeRecipeResponse, String)
    func screenImage(_ image: UIImage) async throws -> ContentScreeningResult
}

// MARK: - Retry Logic

enum RetryableError {
    /// Returns true if the error is worth retrying (network issues, server errors).
    static func isRetryable(_ error: Error) -> Bool {
        // Network-level errors (timeout, no connection, etc.)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .notConnectedToInternet,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }

        // API errors with 5xx status codes
        let description = error.localizedDescription
        if description.contains("error (5") { return true }

        // Gemini/Claude/Fal network errors
        if error is GeminiAPIError {
            if case .networkError = error as! GeminiAPIError { return true }
            return false
        }
        if error is ClaudeAPIError {
            if case .networkError = error as! ClaudeAPIError { return true }
            return false
        }
        if error is FalAPIError {
            if case .networkError = error as! FalAPIError { return true }
            return false
        }

        return false
    }
}

func withExponentialBackoff<T>(
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 1.0,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error

            // Don't retry cancellation
            if error is CancellationError { throw error }

            // Only retry retryable errors
            guard attempt < maxAttempts - 1, RetryableError.isRetryable(error) else {
                throw error
            }

            let delay = baseDelay * pow(2.0, Double(attempt))
            try await Task.sleep(for: .seconds(delay))
        }
    }

    throw lastError!
}
