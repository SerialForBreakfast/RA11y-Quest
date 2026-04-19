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

    /// Persists the "Basics completed" flag.
    func markBasicsCompleted() async

    /// Returns whether the user dismissed the first-run Basics prompt.
    func isBasicsDismissed() async -> Bool

    /// Persists the "Basics dismissed" flag when the user opts out of first-run.
    func markBasicsDismissed() async

    /// Returns whether Lights Off training mode is enabled (visual blackout of gameplay).
    ///
    /// When `true`, games should hide decorative visuals while preserving accessibility
    /// traversal and semantics. Default is `false`.
    func isLightsOffModeEnabled() async -> Bool

    /// Persists the Lights Off mode preference.
    ///
    /// - Parameter enabled: `true` to black out gameplay visuals on the next session.
    func setLightsOffModeEnabled(_ enabled: Bool) async
}
