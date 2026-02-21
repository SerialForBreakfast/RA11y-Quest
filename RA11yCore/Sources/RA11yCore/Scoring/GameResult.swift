import Foundation

// MARK: - GameResult

/// Immutable record of a completed game session's outcome.
///
/// `Codable` for persistence via `StorageComponent`.
/// `Hashable` for use as an associated value in `AppRoute` with `NavigationStack`.
public struct GameResult: Sendable, Codable, Equatable, Hashable {

    /// Stable catalog ID of the game (matches `GameDefinition.id`).
    public let gameID: String

    /// Rank achieved in this session.
    public let rank: GameRank

    /// Active session time in seconds, excluding any pause durations.
    public let timeSeconds: Double

    /// Total mistakes recorded during the session.
    public let mistakes: Int

    /// - Parameters:
    ///   - gameID: Stable catalog ID matching `GameDefinition.id`.
    ///   - rank: Rank derived from thresholds at completion.
    ///   - timeSeconds: Elapsed active time (excluding pauses), in seconds.
    ///   - mistakes: Total mistakes recorded.
    public init(gameID: String, rank: GameRank, timeSeconds: Double, mistakes: Int) {
        self.gameID = gameID
        self.rank = rank
        self.timeSeconds = timeSeconds
        self.mistakes = mistakes
    }

    // MARK: - Comparison

    /// Returns `true` if this result is strictly better than `other`.
    ///
    /// Comparison order (highest priority first):
    /// 1. Higher rank wins.
    /// 2. Equal rank: fewer mistakes wins.
    /// 3. Equal rank and mistakes: faster time wins.
    ///
    /// - Parameter other: The result to compare against.
    public func isBetter(than other: GameResult) -> Bool {
        if rank != other.rank { return rank > other.rank }
        if mistakes != other.mistakes { return mistakes < other.mistakes }
        return timeSeconds < other.timeSeconds
    }
}
