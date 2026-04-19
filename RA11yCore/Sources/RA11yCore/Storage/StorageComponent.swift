// MARK: - BasicsProgressSnapshot

/// Snapshot of the first-run Basics flags used during startup routing.
///
/// Reading both flags in one storage call avoids repeated actor hops on launch and
/// keeps route resolution deterministic.
public struct BasicsProgressSnapshot: Sendable {

    /// Whether the player completed the VoiceOver Basics sequence.
    public let isCompleted: Bool

    /// Whether the player dismissed the first-run prompt without completing Basics.
    public let isDismissed: Bool

    /// Creates a snapshot of the current Basics flags.
    ///
    /// - Parameters:
    ///   - isCompleted: `true` when Basics was completed.
    ///   - isDismissed: `true` when the prompt was dismissed.
    public init(isCompleted: Bool, isDismissed: Bool) {
        self.isCompleted = isCompleted
        self.isDismissed = isDismissed
    }
}

// MARK: - StorageComponent

/// Abstraction over result and progress persistence.
///
/// All methods are `async` to accommodate actor-isolated implementations.
/// This allows the backing store to change (e.g., from `UserDefaults` to SwiftData)
/// without modifying call sites.
///
/// ## Concurrency
/// Conforming types must be `Sendable`. Actor-based conformances (e.g.,
/// `UserDefaultsStorageComponent`) satisfy this automatically.
///
/// ## Best-Result Semantics
/// `saveResultIfBetter(_:)` uses `GameResult.isBetter(than:)` to determine whether
/// the incoming result should replace the stored best. Only completed sessions write
/// results (enforced by `GameSession`).
public protocol StorageComponent: AnyObject, Sendable {

    /// Returns the best stored result for the given game ID, or `nil` if none exists.
    ///
    /// - Parameter gameID: The stable catalog ID from `GameDefinition.id`.
    func bestResult(for gameID: String) async -> GameResult?

    /// Persists `result` only if it is better than the currently stored best.
    ///
    /// If no result exists for the game, the result is always saved.
    /// Uses `GameResult.isBetter(than:)` for comparison.
    ///
    /// - Parameter result: The completed session result to consider saving.
    func saveResultIfBetter(_ result: GameResult) async

    /// Returns whether the VoiceOver Basics sequence has been completed.
    func isBasicsCompleted() async -> Bool

    /// Returns both first-run Basics flags in a single storage read.
    ///
    /// This is the preferred startup API because it avoids multiple cross-actor
    /// hops during route resolution.
    func basicsProgressSnapshot() async -> BasicsProgressSnapshot

    /// Persists the "Basics completed" flag.
    func markBasicsCompleted() async

    /// Returns whether the user dismissed the first-run Basics prompt.
    func isBasicsDismissed() async -> Bool

    /// Returns best stored results for the provided game IDs.
    ///
    /// Implementations should batch the read when possible so hub refresh does not
    /// pay one actor hop per game.
    ///
    /// - Parameter gameIDs: Stable catalog IDs.
    /// - Returns: A dictionary keyed by game ID for IDs that have a stored result.
    func bestResults(for gameIDs: [String]) async -> [String: GameResult]

    /// Persists the "Basics dismissed" flag when the user opts out of first-run.
    func markBasicsDismissed() async
}
