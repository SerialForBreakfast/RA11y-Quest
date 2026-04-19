/// Reusable quest feedback configuration consumed by platform renderers.
///
/// Each quest can supply its own profile while still using the same reducer and
/// coordinator architecture.
public struct QuestFeedbackProfile: Equatable, Sendable {
    /// Human-readable profile name for logging and debugging.
    public let name: String

    /// Cue used when entering the warm band.
    public let warmCue: QuestFeedbackCue

    /// Cue used when entering the near band.
    public let nearCue: QuestFeedbackCue

    /// Cue used when the activation lock is acquired.
    public let lockCue: QuestFeedbackCue

    /// Cue used when the activation lock is lost.
    public let lockLostCue: QuestFeedbackCue

    /// Cue used when the player activates the wrong object.
    public let wrongActivationCue: QuestFeedbackCue

    /// Cue used when the player succeeds.
    public let successCue: QuestFeedbackCue

    /// Cue used when the player times out.
    public let timeoutCue: QuestFeedbackCue

    /// Cue used when the player requests help.
    public let hintCue: QuestFeedbackCue

    /// Creates a reusable profile.
    public init(
        name: String,
        warmCue: QuestFeedbackCue,
        nearCue: QuestFeedbackCue,
        lockCue: QuestFeedbackCue,
        lockLostCue: QuestFeedbackCue,
        wrongActivationCue: QuestFeedbackCue,
        successCue: QuestFeedbackCue,
        timeoutCue: QuestFeedbackCue,
        hintCue: QuestFeedbackCue
    ) {
        self.name = name
        self.warmCue = warmCue
        self.nearCue = nearCue
        self.lockCue = lockCue
        self.lockLostCue = lockLostCue
        self.wrongActivationCue = wrongActivationCue
        self.successCue = successCue
        self.timeoutCue = timeoutCue
        self.hintCue = hintCue
    }
}

public extension QuestFeedbackProfile {
    /// Resonance-oriented cue mapping for Crystal Resonance (Scroll Hunt) v2.
    static let dungeonResonance = QuestFeedbackProfile(
        name: "dungeonResonance",
        warmCue: QuestFeedbackCue(audio: .resonance, haptic: .softTick, cooldownSeconds: 0.25),
        nearCue: QuestFeedbackCue(audio: .resonance, haptic: .proximityPulse, cooldownSeconds: 0.18),
        lockCue: QuestFeedbackCue(audio: .resonance, haptic: .alignmentSnap, cooldownSeconds: 0.0),
        lockLostCue: QuestFeedbackCue(audio: .warningPulse, haptic: .softTick, cooldownSeconds: 0.1),
        wrongActivationCue: QuestFeedbackCue(audio: .mutedError, haptic: .errorTap, cooldownSeconds: 0.0),
        successCue: QuestFeedbackCue(audio: .crystallineSuccess, haptic: .successPulse, cooldownSeconds: 0.0),
        timeoutCue: QuestFeedbackCue(audio: .warningPulse, haptic: .warningTap, cooldownSeconds: 0.0),
        hintCue: QuestFeedbackCue(audio: .hintChime, haptic: .softTick, cooldownSeconds: 0.4)
    )

    /// Light-touch profile suitable for calmer, tutorial-heavy quests.
    static let calmGuidance = QuestFeedbackProfile(
        name: "calmGuidance",
        warmCue: QuestFeedbackCue(audio: .none, haptic: .softTick, cooldownSeconds: 0.35),
        nearCue: QuestFeedbackCue(audio: .none, haptic: .proximityPulse, cooldownSeconds: 0.25),
        lockCue: QuestFeedbackCue(audio: .none, haptic: .alignmentSnap, cooldownSeconds: 0.0),
        lockLostCue: QuestFeedbackCue(audio: .none, haptic: .softTick, cooldownSeconds: 0.15),
        wrongActivationCue: QuestFeedbackCue(audio: .mutedError, haptic: .errorTap, cooldownSeconds: 0.0),
        successCue: QuestFeedbackCue(audio: .crystallineSuccess, haptic: .successPulse, cooldownSeconds: 0.0),
        timeoutCue: QuestFeedbackCue(audio: .warningPulse, haptic: .warningTap, cooldownSeconds: 0.0),
        hintCue: QuestFeedbackCue(audio: .hintChime, haptic: .softTick, cooldownSeconds: 0.4)
    )
}
