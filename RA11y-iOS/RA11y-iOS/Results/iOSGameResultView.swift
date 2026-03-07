import SwiftUI
import RA11yCore

// MARK: - iOSGameResultView

/// Shared result screen displayed by all three training games on completion.
///
/// Accepts a `GameResultPresenter`, an optional game-specific announcement string,
/// and two action closures. Reused across all games — no per-game subclasses.
///
/// ## VoiceOver
/// The result summary (rank + metrics) is a single accessibility element using
/// `GameResultPresenter.accessibilityAnnouncement`. Order: rank → time → mistakes,
/// as required by TICKET-M1-SharedGameResultScreen.
/// If `gameSpecificAnnouncement` is provided, it is appended after the shared summary
/// on a separate line — announced after VoiceOver reads the shared element.
///
/// ## Dynamic Type
/// All text uses semantic font styles from `RA11yFont`; layout scrolls at largest sizes.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSGameResultView: View {

    // MARK: - Properties

    let presenter: GameResultPresenter

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
                actionButtons
            }
            .padding(RA11ySpacing.base)
        }
        .navigationTitle(String(localized: "result.navigationTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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

    /// "Try Again" and "Back to Tavern" action buttons.
    private var actionButtons: some View {
        VStack(spacing: RA11ySpacing.sm) {
            Button(String(localized: "result.playAgain")) {
                onPlayAgain()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(String(localized: "result.returnToHub")) {
                onReturnToHub()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

// MARK: - Preview

#Preview("Legendary") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8.5, mistakes: 0)
            ),
            gameSpecificAnnouncement: "The Enchanter bows. A perfect invocation.",
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}

#Preview("Defeated") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "find-and-focus", rank: .failed, timeSeconds: 46, mistakes: 3)
            ),
            gameSpecificAnnouncement: "The relic vanished. Return when you are ready.",
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}
