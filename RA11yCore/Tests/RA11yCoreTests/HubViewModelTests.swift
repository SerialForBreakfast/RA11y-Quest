import Testing
@testable import RA11yCore

// MARK: - HubViewModelTests

/// Tests for `HubViewModel` — best-result loading and refresh.
///
/// VoiceOver affordance visibility is intentionally not tested here.
/// `HubViewModel` no longer observes VoiceOver state; the hub view reads
/// `@Environment(\.accessibilityVoiceOverEnabled)` directly, which is
/// propagated by SwiftUI and does not require unit verification.
///
/// All tests use `InMemoryStorageComponent` — no disk access, no simulators.
/// `@MainActor` required because `HubViewModel` is `@MainActor`.
@MainActor
struct HubViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        storage: InMemoryStorageComponent = InMemoryStorageComponent()
    ) -> HubViewModel {
        HubViewModel(storage: storage)
    }

    // MARK: - Best Results: Initial State

    /// A freshly created view model has no results until `refreshBestResults()` is called.
    @Test func freshViewModelHasNoBestResults() async {
        let viewModel = makeViewModel()
        #expect(viewModel.bestRank(for: "find-and-focus") == nil)
        #expect(viewModel.bestRank(for: "activate-double-tap") == nil)
        #expect(viewModel.bestRank(for: "scroll-hunt") == nil)
    }

    /// `refreshBestResults()` returns nil for games that have never been played.
    @Test func unplayedGamesHaveNilBestRank() async {
        let viewModel = makeViewModel()
        await viewModel.refreshBestResults()

        #expect(viewModel.bestRank(for: "find-and-focus") == nil)
        #expect(viewModel.bestRank(for: "activate-double-tap") == nil)
        #expect(viewModel.bestRank(for: "scroll-hunt") == nil)
    }

    // MARK: - Best Results: Load from Storage

    /// Results stored before `refreshBestResults()` is called are surfaced correctly.
    @Test func storedResultsLoadOnRefresh() async {
        let storage = InMemoryStorageComponent()
        let legendary = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8.0, mistakes: 0)
        let novice    = GameResult(gameID: "scroll-hunt",    rank: .ok,      timeSeconds: 40.0, mistakes: 2)
        await storage.saveResultIfBetter(legendary)
        await storage.saveResultIfBetter(novice)

        let viewModel = makeViewModel(storage: storage)
        await viewModel.refreshBestResults()

        #expect(viewModel.bestRank(for: "find-and-focus")      == .perfect)
        #expect(viewModel.bestRank(for: "activate-double-tap") == nil)
        #expect(viewModel.bestRank(for: "scroll-hunt")         == .ok)
    }

    // MARK: - Best Results: Refresh

    /// After a first play, `refreshBestResults()` reflects the new result without relaunch.
    @Test func refreshBestResultsReflectsNewlySavedResult() async {
        let storage   = InMemoryStorageComponent()
        let viewModel = makeViewModel(storage: storage)
        await viewModel.refreshBestResults()

        #expect(viewModel.bestRank(for: "find-and-focus") == nil)

        let result = GameResult(gameID: "find-and-focus", rank: .good, timeSeconds: 15.0, mistakes: 1)
        await storage.saveResultIfBetter(result)
        await viewModel.refreshBestResults()

        #expect(viewModel.bestRank(for: "find-and-focus") == .good)
    }

    /// After a second (better) play, `refreshBestResults()` shows the improved rank.
    ///
    /// Validates the full promotion path: Novice → Legendary after `saveResultIfBetter`
    /// correctly stores the best, and `refreshBestResults` reads it.
    @Test func refreshReflectsImprovedBestRankAfterSecondPlay() async {
        let storage = InMemoryStorageComponent()
        let novice  = GameResult(gameID: "find-and-focus", rank: .ok, timeSeconds: 35, mistakes: 2)
        await storage.saveResultIfBetter(novice)

        let viewModel = makeViewModel(storage: storage)
        await viewModel.refreshBestResults()
        #expect(viewModel.bestRank(for: "find-and-focus") == .ok)

        let legendary = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8, mistakes: 0)
        await storage.saveResultIfBetter(legendary)
        await viewModel.refreshBestResults()

        #expect(viewModel.bestRank(for: "find-and-focus") == .perfect)
    }

    /// An unknown game ID returns nil gracefully — no crash, no phantom data.
    @Test func bestRankForUnknownIDReturnsNil() async {
        let viewModel = makeViewModel()
        await viewModel.refreshBestResults()
        #expect(viewModel.bestRank(for: "nonexistent-game") == nil)
    }
}
