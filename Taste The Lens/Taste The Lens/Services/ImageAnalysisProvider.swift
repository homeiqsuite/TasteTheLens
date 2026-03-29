import Foundation
import Supabase

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

        // Supabase edge function errors — retry 5xx but NOT 429 (handled separately)
        if let functionsError = error as? FunctionsError {
            if case .httpError(let code, _) = functionsError {
                return code >= 500
            }
        }

        // Direct edge function errors
        if let edgeError = error as? EdgeFunctionError {
            return edgeError.isRetryable
        }

        // API errors with 5xx status codes
        let description = error.localizedDescription
        if description.contains("error (5") { return true }

        return false
    }

    /// Returns true if the error is a rate limit (429) from an edge function.
    static func isRateLimited(_ error: Error) -> Bool {
        if let functionsError = error as? FunctionsError,
           case .httpError(let code, _) = functionsError {
            return code == 429
        }
        if let edgeError = error as? EdgeFunctionError {
            return edgeError.isRateLimit
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

            // Rate limit errors: retry with longer delay (30s default)
            if RetryableError.isRateLimited(error) {
                guard attempt < maxAttempts - 1 else { throw error }
                try await Task.sleep(for: .seconds(30))
                continue
            }

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

/// Error thrown when an operation exceeds its timeout.
struct TimeoutError: LocalizedError {
    let seconds: TimeInterval
    var errorDescription: String? { "Request timed out after \(Int(seconds)) seconds. Please check your connection and try again." }
}

/// Wraps an async operation with a timeout. Throws `TimeoutError` if the timeout expires.
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(seconds: seconds)
        }
        // Return whichever finishes first; cancel the other
        guard let result = try await group.next() else {
            throw TimeoutError(seconds: seconds)
        }
        group.cancelAll()
        return result
    }
}
