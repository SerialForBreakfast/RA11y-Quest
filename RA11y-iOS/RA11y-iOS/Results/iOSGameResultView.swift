import SwiftUI
import RA11yCore

// MARK: - iOSGameResultView

/// Shared result screen displayed by training games on completion.
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
/// Body copy uses `RA11yFont` where appropriate; rank and headings use ``QuestPaintReadableTextRole``
/// (serif mockup lane) so Dynamic Type still scales.
///
/// ## Theming
/// Uses ``QuestPaintScreen`` with ``QuestLayoutRole/result`` so Enchanter, Crystal/Dungeon, and Banishment share
/// the same illustrated scaffold, iPad column width (**660pt** cap regular), and Dungeon ``scrollHunt`` gutter when applicable.
/// The skill-transfer card uses an explicit leading ``HStack`` so wrapped copy is not clipped on compact widths (store screenshots).
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSGameResultView: View {

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
        QuestPaintScreen(
            ambientImageName: gameKind.questResultAmbientImageName,
            layoutRole: .result,
            gameKind: gameKind
        ) {
            VStack(spacing: RA11ySpacing.lg) {
                resultSummary
                if let gameSpecificAnnouncement {
                    Text(gameSpecificAnnouncement)
                        .multilineTextAlignment(.center)
                        .questPaintReadableText(.bodyEmphasis)
                        .padding(.horizontal, RA11ySpacing.base)
                        .padding(.vertical, RA11ySpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: RA11yRadius.card))
                }
                skillTransferCard
                gestureReminderSection
                QuestGameResultActionStack(
                    onPlayAgain: onPlayAgain,
                    onReturnToHub: onReturnToHub
                )
            }
            .padding(.top, RA11ySpacing.sm)
            .padding(.bottom, RA11ySpacing.md)
        }
        .navigationTitle(String(localized: "result.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .accessibilityIdentifier("gameResult.root")
    }

    // MARK: - Subviews

    /// Rank icon, rank label, time, and mistake count.
    /// Grouped as a single VoiceOver element with the full announcement string.
    private var resultSummary: some View {
        VStack(spacing: RA11ySpacing.sm) {
            Image(systemName: presenter.result.rank.symbolName)
                .font(.system(size: 54))
                .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                .accessibilityHidden(true)

            Text(presenter.result.rank.displayText)
                .multilineTextAlignment(.center)
                .questPaintReadableText(.heroTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: RA11ySpacing.xs) {
                Text(presenter.formattedTime)
                    .questPaintReadableText(.materialCardBody)
                    .font(Font.ra11yHeadline)
                Text(presenter.formattedMistakes)
                    .questPaintReadableText(.materialCardMeta)
            }
        }
        .padding(RA11ySpacing.md)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
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
            HStack(alignment: .top, spacing: RA11ySpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                    .accessibilityHidden(true)
                Text(String(localized: "result.skillTransfer.heading"))
                    .questPaintReadableText(.materialCardTitle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Divider().opacity(0.28)

            Text(skillTransferBody)
                .questPaintReadableText(.materialCardBody)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(skillTransferRealWorld)
                .questPaintReadableText(.materialCardMeta)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(RA11ySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(String(localized: "result.skillTransfer.heading")). \(skillTransferBody) \(skillTransferRealWorld)"
        )
        .accessibilityIdentifier("result.skillTransferCard")
    }

    /// Compact “spell card” echoing the VoiceOver pattern each quest emphasized (linear nav, three-finger scroll, Z scrub).
    private var gestureReminderSection: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(String(localized: "result.gestureReminder.heading"))
                .textCase(.uppercase)
                .questPaintReadableText(.captionGold)
                .tracking(0.35)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            QuestVoiceOverGestureSpellPlate.resultReminder(for: gameKind)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("result.gestureReminder")
    }

    private var skillTransferBody: String {
        switch gameKind {
        case .findAndFocus:
            return String(localized: "result.skillTransfer.findAndFocus.body")
        case .scrollHunt:
            return String(localized: "result.skillTransfer.scrollHunt.body")
        case .banishment:
            return String(localized: "result.skillTransfer.banishment.body")
        }
    }

    private var skillTransferRealWorld: String {
        switch gameKind {
        case .findAndFocus:
            return String(localized: "result.skillTransfer.findAndFocus.realWorld")
        case .scrollHunt:
            return String(localized: "result.skillTransfer.scrollHunt.realWorld")
        case .banishment:
            return String(localized: "result.skillTransfer.banishment.realWorld")
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
        .environment(iOSAppRouter())
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
        .environment(iOSAppRouter())
    }
}
