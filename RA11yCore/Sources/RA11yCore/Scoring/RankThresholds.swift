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

    /// Thresholds for Find & Focus — The Enchanter's Trial (Game 1).
    ///
    /// Per `GameSpec-FindAndFocus.txt` and `GameRules-MVP.txt`:
    /// - Legendary (Perfect): 0 mistakes, ≤10s
    /// - Skilled   (Good):    ≤1 mistake, ≤20s
    /// - Novice    (Ok):      completed,  ≤45s (matches L3 timeout ceiling)
    /// - Defeated  (Failed):  timed out OR ≥5 mistakes (okMaxMistakes = 4 captures the boundary)
    static let findAndFocus = RankThresholds(
        timeoutSeconds:     45,
        perfectMaxTime:     10, perfectMaxMistakes: 0,
        goodMaxTime:        20, goodMaxMistakes:    1,
        okMaxTime:          45, okMaxMistakes:      4
    )

    /// Thresholds for Activate — The Rogue's Gauntlet (Game 2).
    ///
    /// Per `GameSpec-ActivateDoubleTap.txt` and `GameRules-MVP.txt`:
    /// - Legendary (Perfect): 0 mistakes, ≤8s
    /// - Skilled   (Good):    ≤1 mistake, ≤16s
    /// - Novice    (Ok):      completed,  ≤40s
    /// - Defeated  (Failed):  timed out OR ≥5 mistakes
    static let activateDoubleTap = RankThresholds(
        timeoutSeconds:     40,
        perfectMaxTime:      8, perfectMaxMistakes: 0,
        goodMaxTime:        16, goodMaxMistakes:    1,
        okMaxTime:          40, okMaxMistakes:      4
    )

    /// Thresholds for Scroll Hunt — The Dungeon Descent (Game 3).
    ///
    /// Per `GameSpec-ScrollHunt.txt` and `GameRules-MVP.txt`:
    /// - Legendary (Perfect): 0 mistakes, ≤15s
    /// - Skilled   (Good):    ≤1 mistake, ≤30s
    /// - Novice    (Ok):      completed,  ≤60s
    /// - Defeated  (Failed):  timed out OR ≥6 mistakes
    static let scrollHunt = RankThresholds(
        timeoutSeconds:     60,
        perfectMaxTime:     15, perfectMaxMistakes: 0,
        goodMaxTime:        30, goodMaxMistakes:    1,
        okMaxTime:          60, okMaxMistakes:      5
    )
}
