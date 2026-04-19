/// Semantic proximity bands shared across quests that use guided positioning.
///
/// The bands are intentionally generic so games can reuse the same feedback engine
/// without hardcoding quest-specific metaphors such as "resonance" or "seal lock".
public enum QuestFeedbackBand: Int, CaseIterable, Codable, Hashable, Sendable {
    case far
    case warm
    case near
    case locked
}

/// High-level feedback events emitted by game state reducers.
///
/// These intents are platform-agnostic and safe to compute in `RA11yCore`.
/// Platform targets map them to concrete haptic and audio rendering behavior.
public enum QuestFeedbackIntent: Equatable, Sendable {
    /// The player entered a meaningful proximity band.
    case proximityEntered(QuestFeedbackBand)
    /// The player reached the activation window.
    case lockAcquired
    /// The player left the activation window after being locked.
    case lockLost
    /// The player attempted an incorrect activation.
    case wrongActivation
    /// The player completed the objective successfully.
    case success
    /// The player ran out of time or otherwise failed the challenge.
    case timeout
    /// The player explicitly requested help.
    case hint
}

/// Reducer inputs that drive feedback-state transitions.
///
/// Games should reduce raw geometry or gameplay events into these semantic inputs rather
/// than emitting platform feedback directly from scroll handlers.
public enum QuestFeedbackInput: Equatable, Sendable {
    /// Alignment band derived from current gameplay geometry.
    case alignmentBandChanged(QuestFeedbackBand)
    /// The player activated the wrong object or trigger.
    case wrongActivation
    /// The player completed the objective.
    case success
    /// The challenge timed out or failed.
    case timeout
    /// The player explicitly requested a hint.
    case hintRequested
}

/// Internal reducer state used to prevent feedback spam and preserve transition semantics.
public struct QuestFeedbackState: Equatable, Sendable {
    /// The current reduced proximity band, if one has been established.
    public var currentBand: QuestFeedbackBand?

    /// Creates a new feedback state.
    ///
    /// - Parameter currentBand: Initial proximity band when restoring or testing state.
    public init(currentBand: QuestFeedbackBand? = nil) {
        self.currentBand = currentBand
    }
}

/// Lightweight cue family identifiers that platform targets can map to concrete renderers.
public enum QuestFeedbackAudioFamily: String, Codable, Hashable, Sendable {
    case none
    case resonance
    case mutedError
    case crystallineSuccess
    case warningPulse
    case hintChime
}

/// Lightweight haptic-family identifiers that platform targets can map to concrete generators.
public enum QuestFeedbackHapticFamily: String, Codable, Hashable, Sendable {
    case none
    case softTick
    case proximityPulse
    case alignmentSnap
    case errorTap
    case successPulse
    case warningTap
}

/// A reusable cue definition for one semantic feedback event.
public struct QuestFeedbackCue: Equatable, Sendable {
    /// The audio family to render.
    public let audio: QuestFeedbackAudioFamily

    /// The haptic family to render.
    public let haptic: QuestFeedbackHapticFamily

    /// Suggested debounce window in seconds before replaying the same semantic cue.
    public let cooldownSeconds: Double

    /// Creates a cue definition.
    ///
    /// - Parameters:
    ///   - audio: Audio family identifier.
    ///   - haptic: Haptic family identifier.
    ///   - cooldownSeconds: Suggested replay debounce interval.
    public init(
        audio: QuestFeedbackAudioFamily,
        haptic: QuestFeedbackHapticFamily,
        cooldownSeconds: Double
    ) {
        self.audio = audio
        self.haptic = haptic
        self.cooldownSeconds = cooldownSeconds
    }
}
