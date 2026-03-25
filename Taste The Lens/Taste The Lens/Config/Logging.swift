import os

/// Creates a logger for the given category.
/// In Production builds, returns a disabled logger to suppress all log output.
func makeLogger(category: String) -> Logger {
    #if PRODUCTION
    return Logger(.disabled)
    #else
    return Logger(subsystem: "com.eightgates.TasteTheLens", category: category)
    #endif
}
