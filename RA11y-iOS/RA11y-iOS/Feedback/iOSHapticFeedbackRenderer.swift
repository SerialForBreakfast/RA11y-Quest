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
    private let selectionChanged = UISelectionFeedbackGenerator()

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
        selectionChanged.prepare()
    }

    func render(intent: QuestFeedbackIntent, cue: QuestFeedbackCue) {
        switch cue.haptic {
        case .none:
            return
        case .softTick:
            lightImpact.prepare()
            lightImpact.impactOccurred(intensity: 0.55)
        case .selectionChanged:
            // `UISelectionFeedbackGenerator` is easy to miss with VoiceOver; pair with a light impact.
            selectionChanged.prepare()
            selectionChanged.selectionChanged()
            lightImpact.prepare()
            lightImpact.impactOccurred(intensity: 0.95)
        case .proximityPulse:
            mediumImpact.prepare()
            mediumImpact.impactOccurred(intensity: 0.7)
        case .alignmentSnap:
            rigidImpact.prepare()
            rigidImpact.impactOccurred(intensity: 0.95)
        case .errorTap:
            notification.prepare()
            notification.notificationOccurred(.error)
        case .successPulse:
            notification.prepare()
            notification.notificationOccurred(.success)
        case .warningTap:
            notification.prepare()
            notification.notificationOccurred(.warning)
        }

        RA11yLogger.feedback.debug(
            "Haptic cue rendered — intent: \(String(describing: intent)), family: \(cue.haptic.rawValue)"
        )
    }
}
