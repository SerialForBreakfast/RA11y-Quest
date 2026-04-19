import Observation

/// User-facing feedback preferences shared across quests on iOS.
///
/// This object is intentionally small and environment-friendly so multiple game views can
/// respect the same sound / haptics policy without duplicating state.
@Observable
@MainActor
final class iOSFeedbackSettings {

    /// Whether non-VoiceOver custom audio feedback is enabled.
    var soundEnabled: Bool

    /// Whether haptic feedback is enabled.
    var hapticsEnabled: Bool

    /// Whether spoken hint copy may be layered in addition to haptics/audio.
    var spokenHintsEnabled: Bool

    /// When `true`, prefer quieter / sparser feedback profiles.
    var calmMode: Bool

    init(
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        spokenHintsEnabled: Bool = true,
        calmMode: Bool = false
    ) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.spokenHintsEnabled = spokenHintsEnabled
        self.calmMode = calmMode
    }
}
