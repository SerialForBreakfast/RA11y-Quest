import Foundation
import RA11yCore

/// Coordinates semantic quest feedback on iOS.
///
/// Game code sends semantic `QuestFeedbackInput` values to this coordinator. The coordinator
/// reduces them into reusable intents, applies per-cue cooldowns, and forwards resulting
/// renders to the audio and haptic backends.
@MainActor
final class iOSQuestFeedbackCoordinator {

    private var profile: QuestFeedbackProfile
    private let settings: iOSFeedbackSettings
    private let audioRenderer: iOSAudioFeedbackRendering
    private let hapticRenderer: iOSHapticFeedbackRendering

    private var state = QuestFeedbackState()
    private var lastRenderByKey: [String: CFAbsoluteTime] = [:]

    init(
        profile: QuestFeedbackProfile,
        settings: iOSFeedbackSettings,
        audioRenderer: iOSAudioFeedbackRendering = iOSAudioFeedbackRenderer(),
        hapticRenderer: iOSHapticFeedbackRendering = iOSHapticFeedbackRenderer()
    ) {
        self.profile = profile
        self.settings = settings
        self.audioRenderer = audioRenderer
        self.hapticRenderer = hapticRenderer
    }

    /// Processes a semantic gameplay input and renders any resulting quest feedback.
    func process(_ input: QuestFeedbackInput) {
        let intents = QuestFeedbackReducer.reduce(state: &state, input: input)
        for intent in intents {
            render(intent)
        }
    }

    /// Clears reducer and cooldown state, for example when restarting a level.
    func reset() {
        state = QuestFeedbackState()
        lastRenderByKey.removeAll()
    }

    /// Replaces the active feedback profile, optionally clearing reducer and cooldown state.
    ///
    /// - Parameters:
    ///   - profile: New quest feedback profile to apply for subsequent renders.
    ///   - resetState: Whether reducer/cooldown state should also be cleared.
    func updateProfile(_ profile: QuestFeedbackProfile, resetState: Bool = false) {
        self.profile = profile
        if resetState {
            reset()
        }
    }

    private func render(_ intent: QuestFeedbackIntent) {
        let cue = cue(for: intent)
        let now = CFAbsoluteTimeGetCurrent()
        let key = cooldownKey(for: intent)
        let last = lastRenderByKey[key] ?? -.infinity
        guard now - last >= cue.cooldownSeconds else { return }
        lastRenderByKey[key] = now

        if settings.hapticsEnabled {
            hapticRenderer.render(intent: intent, cue: cue)
        }
        if settings.soundEnabled {
            audioRenderer.render(intent: intent, cue: cue)
        }
    }

    private func cue(for intent: QuestFeedbackIntent) -> QuestFeedbackCue {
        switch intent {
        case .proximityEntered(.far):
            return profile.warmCue
        case .proximityEntered(.warm):
            return profile.warmCue
        case .proximityEntered(.near):
            return profile.nearCue
        case .proximityEntered(.locked):
            return profile.lockCue
        case .lockAcquired:
            return profile.lockCue
        case .lockLost:
            return profile.lockLostCue
        case .wrongActivation:
            return profile.wrongActivationCue
        case .success:
            return profile.successCue
        case .timeout:
            return profile.timeoutCue
        case .hint:
            return profile.hintCue
        }
    }

    private func cooldownKey(for intent: QuestFeedbackIntent) -> String {
        switch intent {
        case .proximityEntered(let band):
            return "proximity-\(band.rawValue)"
        case .lockAcquired:
            return "lock-acquired"
        case .lockLost:
            return "lock-lost"
        case .wrongActivation:
            return "wrong-activation"
        case .success:
            return "success"
        case .timeout:
            return "timeout"
        case .hint:
            return "hint"
        }
    }
}
