import OSLog
import UIKit
import RA11yCore

/// Renders semantic feedback intents as iOS haptics.
@MainActor
protocol iOSHapticFeedbackRendering {
    /// Renders one semantic feedback cue.
    func render(intent: QuestFeedbackIntent, cue: QuestFeedbackCue)
}

/// Default UIKit-backed haptic renderer for RA11y quest feedback.
@MainActor
final class iOSHapticFeedbackRenderer: iOSHapticFeedbackRendering {

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
    }

    func render(intent: QuestFeedbackIntent, cue: QuestFeedbackCue) {
        switch cue.haptic {
        case .none:
            return
        case .softTick:
            lightImpact.impactOccurred(intensity: 0.55)
        case .proximityPulse:
            mediumImpact.impactOccurred(intensity: 0.7)
        case .alignmentSnap:
            rigidImpact.impactOccurred(intensity: 0.95)
        case .errorTap:
            notification.notificationOccurred(.error)
        case .successPulse:
            notification.notificationOccurred(.success)
        case .warningTap:
            notification.notificationOccurred(.warning)
        }

        RA11yLogger.feedback.debug(
            "Haptic cue rendered — intent: \(String(describing: intent)), family: \(cue.haptic.rawValue)"
        )
    }
}
