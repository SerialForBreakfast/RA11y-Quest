// MARK: - GameSessionState

/// All possible states of a `GameSession`.
///
/// The state machine enforces valid transition ordering.
/// Only `.completed` carries a result; `.abandoned` does not.
public enum GameSessionState: Equatable, Sendable {

    /// Session has been created but not yet started.
    case idle

    /// Session is actively running. Time is accruing.
    case running

    /// Session is temporarily suspended (e.g., app backgrounded).
    /// Elapsed time is preserved; resuming continues from where it left off.
    case paused

    /// Session ended successfully. The associated `GameResult` has been evaluated
    /// and written to storage (if it is the best result for the game).
    case completed(GameResult)

    /// Session ended without a result — due to timeout, VoiceOver being disabled
    /// mid-game, or the user leaving the game screen. No storage write occurs.
    case abandoned
}

// MARK: - GameSessionError

/// Errors thrown for invalid state transitions in `GameSession`.
public enum GameSessionError: Error, Sendable {

    /// The requested transition is not permitted from the current state.
    ///
    /// - Parameters:
    ///   - current: String description of the current state.
    ///   - requested: Name of the operation that was attempted.
    case invalidTransition(current: String, requested: String)
}
