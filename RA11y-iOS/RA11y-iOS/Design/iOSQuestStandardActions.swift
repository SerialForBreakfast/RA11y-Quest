import SwiftUI
import RA11yCore

// MARK: - Full-width primary CTA

/// Prominent full-width button used for **Try Again**, **Begin**, **Continue**, and other primary quest actions.
///
/// Keeps ``ButtonStyle/borderedProminent``, large control size, tavern accent tint, and max-width alignment
/// consistent across games and the shared result screen.
struct QuestStandardPrimaryButton: View {

    let title: String
    let action: () -> Void
    var accessibilityIdentifier: String?
    var accessibilityHint: String?

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .modifier(AccessibilityIdentifierModifier(id: accessibilityIdentifier))
        .modifier(AccessibilityHintModifier(hint: accessibilityHint))
    }
}

// MARK: - Full-width secondary CTA

/// Bordered full-width button for **Back to Tavern** and other secondary exits.
struct QuestStandardSecondaryButton: View {

    let title: String
    let action: () -> Void
    var accessibilityIdentifier: String?
    var accessibilityHint: String?

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .modifier(AccessibilityIdentifierModifier(id: accessibilityIdentifier))
        .modifier(AccessibilityHintModifier(hint: accessibilityHint))
    }
}

// MARK: - Game result footer

/// Shared **Try Again** / **Back to Tavern** column, or **Continue Basics** when ``iOSAppRouter/isInBasicsSequence`` is true.
///
/// ## Concurrency
/// Reads ``iOSAppRouter`` from the environment; must be hosted under a navigation stack that injects the router.
struct QuestGameResultActionStack: View {

    @Environment(iOSAppRouter.self) private var router

    let onPlayAgain: () -> Void
    let onReturnToHub: () -> Void

    var body: some View {
        if router.isInBasicsSequence {
            QuestStandardPrimaryButton(
                title: String(localized: "basicsSequence.continueBasics"),
                action: { router.popForBasicsContinue() },
                accessibilityIdentifier: "result.continueBasics",
                accessibilityHint: String(localized: "basicsSequence.continueBasics.a11yHint")
            )
        } else {
            VStack(spacing: RA11ySpacing.sm) {
                QuestStandardPrimaryButton(
                    title: String(localized: "result.playAgain"),
                    action: onPlayAgain,
                    accessibilityIdentifier: "result.playAgain",
                    accessibilityHint: String(localized: "result.a11y.playAgain.hint")
                )
                QuestStandardSecondaryButton(
                    title: String(localized: "result.returnToHub"),
                    action: onReturnToHub,
                    accessibilityIdentifier: "result.returnToHub",
                    accessibilityHint: String(localized: "result.a11y.returnToHub.hint")
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Optional modifiers (avoid empty modifiers changing type)

private struct AccessibilityIdentifierModifier: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

private struct AccessibilityHintModifier: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
