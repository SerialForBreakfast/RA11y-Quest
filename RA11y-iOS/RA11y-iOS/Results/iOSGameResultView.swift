import SwiftUI
import RA11yCore

// MARK: - iOSGameResultView

/// Shared result screen displayed by all three training games on completion.
///
/// Accepts a `GameResultPresenter` and two action closures. The view is reused across
/// all games — no per-game subclasses or duplicates.
///
/// ## VoiceOver
/// The result summary (rank + metrics) is collapsed into a single accessibility element
/// using the full announcement string from `GameResultPresenter.accessibilityAnnouncement`.
/// Announced order: rank → time → mistakes, as required by TICKET-M1-SharedGameResultScreen.
///
/// ## Dynamic Type
/// All text uses semantic font styles from `RA11yFont`; layout scrolls at largest sizes.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSGameResultView: View {

    // MARK: - Properties

    let presenter: GameResultPresenter

    /// Called when the user taps "Play Again". Restarts the same game.
    /// Wired to a game-specific restart in M5+; pops to hub until then.
    let onPlayAgain: () -> Void

    /// Called when the user taps "Return to Hub". Pops the navigation stack to root.
    let onReturnToHub: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: RA11ySpacing.xl) {
                resultSummary
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

    /// "Play Again" and "Return to Hub" action buttons.
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

#Preview("Perfect") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8.5, mistakes: 0)
            ),
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}

#Preview("Failed") {
    NavigationStack {
        iOSGameResultView(
            presenter: GameResultPresenter(
                result: GameResult(gameID: "find-and-focus", rank: .failed, timeSeconds: 46, mistakes: 3)
            ),
            onPlayAgain: {},
            onReturnToHub: {}
        )
    }
}
