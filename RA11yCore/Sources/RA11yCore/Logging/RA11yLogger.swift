import OSLog

/// Provides named OSLog loggers for each RA11y subsystem.
///
/// All loggers share the `com.showblender.RA11y` subsystem, enabling
/// consistent filtering in Console.app (e.g., subsystem:com.showblender.RA11y).
/// Each category corresponds to one feature area for fine-grained filtering.
///
/// Usage:
/// ```swift
/// RA11yLogger.navigation.debug("Pushing route: hub")
/// RA11yLogger.storage.error("Failed to persist result: \(error)")
/// ```
///
/// - Note: Never log user-identifiable data. Prefer `%{private}@` for sensitive values.
public enum RA11yLogger {
    private static let subsystem = "com.showblender.RA11y"

    /// Navigation and routing events (route pushes, pops, resets).
    public static let navigation = Logger(subsystem: subsystem, category: "navigation")

    /// Storage read/write events (best result persistence, flags).
    public static let storage = Logger(subsystem: subsystem, category: "storage")

    /// VoiceOver state changes and gating decisions.
    public static let voiceOver = Logger(subsystem: subsystem, category: "voiceOver")

    /// Game session lifecycle transitions (start, pause, complete, abandon).
    public static let gameSession = Logger(subsystem: subsystem, category: "gameSession")

    /// Score evaluation and best-result comparisons.
    public static let scoring = Logger(subsystem: subsystem, category: "scoring")
}
