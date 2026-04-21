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
    ///   - mistakes: Total mistakes recorded (include bucket mistakes via `bucketMistakes()`).
    /// - Returns: The highest rank the session qualifies for, or `.failed`.
    public func evaluate(timeSeconds: Double, mistakes: Int) -> GameRank {
        guard timeSeconds <= timeoutSeconds else { return .failed }
        if timeSeconds <= perfectMaxTime && mistakes <= perfectMaxMistakes { return .perfect }
        if timeSeconds <= goodMaxTime    && mistakes <= goodMaxMistakes    { return .good }
        if timeSeconds <= okMaxTime      && mistakes <= okMaxMistakes      { return .ok }
        return .failed
    }

    // MARK: - Bucket Mistake Calculation

    /// Computes time-based "bucket" mistake penalties per `GameSpec-FindAndFocus.txt`.
    ///
    /// The first bucket (0–`bucketSize` seconds) is free; each subsequent full bucket
    /// beyond that adds one penalty mistake. Used by the Enchanter's Trial (and any
    /// future game that uses bucket penalties) to add time-pressure mistakes to the session
    /// before calling `GameSession.complete()`.
    ///
    /// ## Spec Reference
    /// > "Bucket size: 10 seconds. Each full 10s bucket beyond the first adds +1 mistake.
    /// > Example: 0–10s → +0; 10–20s → +1; 20–30s → +2."
    ///
    /// - Parameters:
    ///   - timeSeconds: Elapsed time at completion.
    ///   - bucketSize: Size of each bucket in seconds. Defaults to 10.
    /// - Returns: Number of bucket-penalty mistakes to record (≥ 0).
    public static func bucketMistakes(timeSeconds: Double, bucketSize: Double = 10) -> Int {
        guard timeSeconds > 0, bucketSize > 0 else { return 0 }
        // ceil(t / bucketSize) gives the number of buckets touched.
        // Subtract 1 for the free first bucket.
        return max(0, Int(ceil(timeSeconds / bucketSize)) - 1)
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

    /// Thresholds for Crystal Resonance (Game 2; catalog id `scroll-hunt`).
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

    /// Thresholds for The Banishment (`the-banishment`) — timed gauntlet (tower + Lights Off).
    ///
    /// Greybox tuning: one continuous scored session after the practice ward; `timeoutSeconds`
    /// must match the iOS playfield countdown for The Banishment.
    static let banishment = RankThresholds(
        timeoutSeconds:     55,
        perfectMaxTime:     14, perfectMaxMistakes: 0,
        goodMaxTime:        28, goodMaxMistakes:    1,
        okMaxTime:          55, okMaxMistakes:      4
    )
}
