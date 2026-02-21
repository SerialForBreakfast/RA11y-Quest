import Foundation

// MARK: - RankThresholds

/// Configurable thresholds used to derive a `GameRank` from elapsed time and mistake count.
///
/// Evaluation proceeds top-down: Perfect is checked first, then Good, then Ok.
/// Any session exceeding `timeoutSeconds` is immediately ranked `.failed`,
/// regardless of mistake count.
///
/// Per-game presets are provided as static extension members.
public struct RankThresholds: Sendable {

    /// Maximum elapsed time (in seconds) before the session is automatically ranked `.failed`.
    public let timeoutSeconds: Double

    public let perfectMaxTime: Double
    public let perfectMaxMistakes: Int

    public let goodMaxTime: Double
    public let goodMaxMistakes: Int

    public let okMaxTime: Double
    public let okMaxMistakes: Int

    /// - Parameters:
    ///   - timeoutSeconds: Hard ceiling; sessions over this are ranked `.failed`.
    ///   - perfectMaxTime: Upper time bound for `.perfect` rank.
    ///   - perfectMaxMistakes: Upper mistake bound for `.perfect` rank.
    ///   - goodMaxTime: Upper time bound for `.good` rank.
    ///   - goodMaxMistakes: Upper mistake bound for `.good` rank.
    ///   - okMaxTime: Upper time bound for `.ok` rank.
    ///   - okMaxMistakes: Upper mistake bound for `.ok` rank.
    public init(
        timeoutSeconds: Double,
        perfectMaxTime: Double, perfectMaxMistakes: Int,
        goodMaxTime: Double,   goodMaxMistakes: Int,
        okMaxTime: Double,     okMaxMistakes: Int
    ) {
        self.timeoutSeconds    = timeoutSeconds
        self.perfectMaxTime    = perfectMaxTime
        self.perfectMaxMistakes = perfectMaxMistakes
        self.goodMaxTime       = goodMaxTime
        self.goodMaxMistakes   = goodMaxMistakes
        self.okMaxTime         = okMaxTime
        self.okMaxMistakes     = okMaxMistakes
    }

    // MARK: - Evaluation

    /// Derives a `GameRank` from the given elapsed time and mistake count.
    ///
    /// - Parameters:
    ///   - timeSeconds: Elapsed active session time.
    ///   - mistakes: Total mistakes recorded.
    /// - Returns: The highest rank the session qualifies for, or `.failed`.
    public func evaluate(timeSeconds: Double, mistakes: Int) -> GameRank {
        guard timeSeconds <= timeoutSeconds else { return .failed }
        if timeSeconds <= perfectMaxTime && mistakes <= perfectMaxMistakes { return .perfect }
        if timeSeconds <= goodMaxTime    && mistakes <= goodMaxMistakes    { return .good }
        if timeSeconds <= okMaxTime      && mistakes <= okMaxMistakes      { return .ok }
        return .failed
    }
}

// MARK: - Per-Game Presets

public extension RankThresholds {

    /// Thresholds for Find & Focus (Game 1 — Simon Says).
    ///
    /// Perfect: ≤15s, 0 mistakes. Timeout: 45s.
    static let findAndFocus = RankThresholds(
        timeoutSeconds:     45,
        perfectMaxTime:     15, perfectMaxMistakes: 0,
        goodMaxTime:        25, goodMaxMistakes:    1,
        okMaxTime:          45, okMaxMistakes:      2
    )

    /// Thresholds for Activate (Game 2 — Bomb Defusal).
    ///
    /// Perfect: ≤20s, 0 mistakes. Timeout: 60s.
    static let activateDoubleTap = RankThresholds(
        timeoutSeconds:     60,
        perfectMaxTime:     20, perfectMaxMistakes: 0,
        goodMaxTime:        35, goodMaxMistakes:    1,
        okMaxTime:          60, okMaxMistakes:      2
    )

    /// Thresholds for Scroll Hunt (Game 3 — Dungeon Crawl).
    ///
    /// Perfect: ≤15s, 0 mistakes. Timeout: 60s.
    static let scrollHunt = RankThresholds(
        timeoutSeconds:     60,
        perfectMaxTime:     15, perfectMaxMistakes: 0,
        goodMaxTime:        30, goodMaxMistakes:    1,
        okMaxTime:          60, okMaxMistakes:      2
    )
}
