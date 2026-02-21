// MARK: - GameStartDecision

/// The routing outcome when a user attempts to start a training game.
///
/// Evaluated by `GameStartDecision.evaluate(kind:provider:)` against the current
/// VoiceOver state. The result is mapped to an `AppRoute` in the iOS layer.
///
/// Keeping this type in `RA11yCore` allows routing logic to be unit-tested
/// without any UIKit or SwiftUI dependencies.
public enum GameStartDecision: Equatable, Sendable {

    /// VoiceOver is active — proceed directly to the game.
    case proceed(kind: GameKind)

    /// VoiceOver is inactive — show the "VoiceOver required" interstitial.
    /// The game `kind` is carried so the interstitial can resume to the correct game
    /// once the user enables VoiceOver.
    case requireVoiceOver(kind: GameKind)

    // MARK: - Evaluation

    /// Evaluates the start-game routing decision against the current VoiceOver state.
    ///
    /// - Parameters:
    ///   - kind: The game the user is attempting to start.
    ///   - provider: Source of current VoiceOver state. Inject a `StubVoiceOverStateProvider`
    ///     in tests to control the outcome deterministically.
    /// - Returns: `.proceed` if VoiceOver is running; `.requireVoiceOver` otherwise.
    public static func evaluate(
        kind: GameKind,
        provider: some VoiceOverStateProvider
    ) -> GameStartDecision {
        provider.isVoiceOverRunning ? .proceed(kind: kind) : .requireVoiceOver(kind: kind)
    }
}
