import SwiftUI
import RA11yCore

// MARK: - iOSGameResultView

/// Shared result screen displayed by all three training games on completion.
///
/// Accepts a `GameResultPresenter`, the `GameKind` (used to render the skill-transfer
/// card), an optional game-specific announcement string, and two action closures.
/// Reused across all games — no per-game subclasses.
///
/// ## Skill Transfer Card
/// Below the rank summary, a "What You Learned" card explicitly bridges the game's
/// skill back to real-world VoiceOver usage. This is the critical step from game
/// mechanic → transferable behaviour that is missing from most AT onboarding.
///
/// ## VoiceOver
/// The result summary (rank + metrics) is a single accessibility element using
/// `GameResultPresenter.accessibilityAnnouncement`. Order: rank → time → mistakes.
/// If `gameSpecificAnnouncement` is provided, it is appended after the shared summary
/// on a separate line.
///
/// ## Dynamic Type
/// All text uses semantic font styles from `RA11yFont`; layout scrolls at largest sizes.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSGameResultView: View {

    // MARK: - Environment

    @Environment(iOSAppRouter.self) private var router

    // MARK: - Properties

    let presenter: GameResultPresenter

    /// The kind of game just completed — drives the skill-transfer card content.
    let gameKind: GameKind

    /// Optional game-specific flavor text shown below the rank summary.
    ///
    /// Each game defines per-rank strings in the localization catalog (e.g.,
    /// `simon.results.legendary`). Nil when no game-specific copy is available.
    let gameSpecificAnnouncement: String?

    /// Called when the user taps "Try Again". Restarts the same game.
    let onPlayAgain: () -> Void

    /// Called when the user taps "Back to Tavern". Pops to hub root.
    let onReturnToHub: () -> Void

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: RA11ySpacing.xl) {
                    resultSummary
                    if let gameSpecificAnnouncement {
                        Text(gameSpecificAnnouncement)
                            .font(.ra11yBody)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, RA11ySpacing.base)
                    }
                    skillTransferCard
                    actionButtons
                }
                .padding(RA11ySpacing.base)
                .frame(width: geo.size.width)
                .frame(maxWidth: .infinity)
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "result.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("gameResult.root")
    }

    // MARK: - Subviews

    /// Rank icon, rank label, time, and mistake count.
    /// Grouped as a single VoiceOver element with the full announcement string.
    private var resultSummary: some View {
        VStack(spacing: RA11ySpacing.md) {
            Image(systemName: presenter.result.rank.symbolName)
                .font(.system(size: 72))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            Text(presenter.result.rank.displayText)
                .font(.ra11yLargeTitle)
                .bold()

            VStack(spacing: RA11ySpacing.xs) {
                Text(presenter.formattedTime)
                    .font(.ra11yHeadline)
                Text(presenter.formattedMistakes)
                    .font(.ra11yBody)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presenter.accessibilityAnnouncement)
    }

    /// Skill transfer card bridging the game mechanic to real-world VoiceOver use.
    ///
    /// Explicitly names the gesture or behaviour the player just practised and shows
    /// where it applies in any iOS app. This is the critical pedagogical step from
    /// "I passed the game" → "I know what to do in the App Store."
    private var skillTransferCard: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Label(String(localized: "result.skillTransfer.heading"), systemImage: "lightbulb.fill")
                .font(.ra11ySubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Divider()

            Text(skillTransferBody)
                .font(.ra11yBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(skillTransferRealWorld)
                .font(.ra11ySubheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "result.skillTransfer.heading")). \(skillTransferBody) \(skillTransferRealWorld)"
        )
        .accessibilityIdentifier("result.skillTransferCard")
    }

    private var skillTransferBody: String {
        switch gameKind {
        case .findAndFocus:
            return String(localized: "result.skillTransfer.findAndFocus.body")
        case .activateDoubleTap:
            return String(localized: "result.skillTransfer.activateDoubleTap.body")
        case .scrollHunt:
            return String(localized: "result.skillTransfer.scrollHunt.body")
        }
    }

    private var skillTransferRealWorld: String {
        switch gameKind {
        case .findAndFocus:
            return String(localized: "result.skillTransfer.findAndFocus.realWorld")
        case .activateDoubleTap:
            return String(localized: "result.skillTransfer.activateDoubleTap.realWorld")
        case .scrollHunt:
            return String(localized: "result.skillTransfer.scrollHunt.realWorld")
        }
    }

    /// Action buttons — adapts to Basics sequence context.
    ///
    /// In the M4 guided Basics sequence, replaces the normal "Try Again" / "Back to
    /// Tavern" pair with a single "Continue Basics" button that pops back to
    /// `iOSBasicsSequenceView`. In standard play the original two buttons are shown.
    @ViewBuilder
    private var actionButtons: some View {
        if router.isInBasicsSequence {
            Button(String(localized: "basicsSequence.continueBasics")) {
                router.popForBasicsContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("result.continueBasics")
            .accessibilityHint(String(localized: "basicsSequence.continueBasics.a11yHint"))
        } else {
            VStack(spacing: RA11ySpacing.sm) {
                Button(String(localized: "result.playAgain")) {
                    onPlayAgain()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("result.playAgain")
                .accessibilityHint(String(localized: "result.a11y.playAgain.hint"))

                Button(String(localized: "result.returnToHub")) {
                    onReturnToHub()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("result.returnToHub")
                .accessibilityHint(String(localized: "result.a11y.returnToHub.hint"))
            }
        }
    }
}

// MARK: - Preview

#Preview("Legendary — Enchanter") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8.5, mistakes: 0)
            ),
            gameKind: .findAndFocus,
            gameSpecificAnnouncement: "The Enchanter bows. A perfect invocation.",
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}

#Preview("Defeated — Rogue") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "activate-double-tap", rank: .failed, timeSeconds: 40, mistakes: 3)
            ),
            gameKind: .activateDoubleTap,
            gameSpecificAnnouncement: "The trap room claimed you. Study the seals and return.",
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}

#Preview("Skilled — Crystal Resonance") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "scroll-hunt", rank: .good, timeSeconds: 28, mistakes: 1)
            ),
            gameKind: .scrollHunt,
            gameSpecificAnnouncement: "Skilled explorer. The vault yielded to you.",
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}
