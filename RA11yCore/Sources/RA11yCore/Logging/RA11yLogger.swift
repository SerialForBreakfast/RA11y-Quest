import Foundation
import OSLog

/// Provides named OSLog loggers for each RA11y subsystem.
///
/// All loggers share the `com.showblender.RA11y` subsystem, enabling
/// consistent filtering in Console.app (e.g., subsystem:com.showblender.RA11y).
/// Each category corresponds to one feature area for fine-grained filtering.
///
/// ## Usage
/// ```swift
/// RA11yLogger.navigation.debug("Pushing route: hub")
/// RA11yLogger.storage.error("Failed to persist result: \(error)")
/// ```
///
/// ## Startup Performance Tracing
/// Use `RA11yLogger.startup` for milestone messages visible in Console.app.
/// Use `RA11yLogger.startupSignposter` for timed intervals visible in Instruments
/// under the "Points of Interest" instrument. Filter by:
///   subsystem = com.showblender.RA11y, category = startup
///
/// ```swift
/// let state = RA11yLogger.startupSignposter.beginInterval("myPhase")
/// defer { RA11yLogger.startupSignposter.endInterval("myPhase", state) }
/// // ... async work ...
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

    /// App startup phase milestones and hangs.
    ///
    /// Logs key moments from cold start through the hub becoming interactive.
    /// Visible in Console.app filtered by subsystem + category = "startup".
    public static let startup = Logger(subsystem: subsystem, category: "startup")

    /// Timed interval signposter for startup phases.
    ///
    /// Produces intervals visible in Instruments → "Points of Interest" instrument.
    /// Pair every `beginInterval` with a matching `endInterval` — use `defer` in
    /// async functions to guarantee the interval closes even on early exit.
    ///
    /// ## Concurrency
    /// `OSSignposter` is safe to use across actor boundaries; `beginInterval`
    /// and `endInterval` may be called from any isolation context.
    public static let startupSignposter = OSSignposter(subsystem: subsystem, category: "startup")

    /// Bracketed wall-clock time plus monotonic system uptime for correlating startup
    /// log lines in Console.app when diagnosing hangs (attach timestamps to each milestone).
    ///
    /// Uptime restarts on device reboot and is unaffected by user date changes.
    ///
    /// - Note: Allocates a fresh `ISO8601DateFormatter` per call so the package stays
    ///   free of non-`Sendable` static formatter state under Swift 6.
    public static func startupTimestampTag() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let wall = formatter.string(from: Date())
        let uptime = ProcessInfo.processInfo.systemUptime
        return "[\(wall) uptime=\(String(format: "%.3f", uptime))s]"
    }
}
