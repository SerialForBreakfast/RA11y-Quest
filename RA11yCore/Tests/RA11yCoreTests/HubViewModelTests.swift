import Testing
@testable import RA11yCore

// MARK: - HubViewModelTests

/// Tests for `HubViewModel` — VoiceOver affordance visibility and best-result loading.
///
/// Covers:
/// - `showHelpAffordance` driven by VoiceOver state (TICKET-M2-HelpAffordance-Visibility)
/// - `bestResults` / `bestRank(for:)` driven by StorageComponent (TICKET-M3-Hub-UI-Progress)
///
/// All tests use `StubVoiceOverStateProvider` and `InMemoryStorageComponent` —
/// no UIKit, no system state, no disk access.
/// `@MainActor` required because `HubViewModel` is `@MainActor`.
@MainActor
struct HubViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        isVoiceOverRunning: Bool,
        stateChanges: AsyncStream<Bool> = AsyncStream { _ in },
        storage: InMemoryStorageComponent = InMemoryStorageComponent()
    ) -> HubViewModel {
        let stub = StubVoiceOverStateProvider(
            isVoiceOverRunning: isVoiceOverRunning,
            stateChanges: stateChanges
        )
        return HubViewModel(voiceOverProvider: stub, storage: storage)
    }

    // MARK: - Help Affordance: Initial State

    /// VO ON → affordance is absent from hierarchy (TICKET-M2-HelpAffordance-Visibility).
    @Test func voiceOverOnSetsShowHelpAffordanceToFalse() {
        let viewModel = makeViewModel(isVoiceOverRunning: true)
        #expect(viewModel.showHelpAffordance == false)
    }

    /// VO OFF → affordance is present; user may need guidance.
    @Test func voiceOverOffSetsShowHelpAffordanceToTrue() {
        let viewModel = makeViewModel(isVoiceOverRunning: false)
        #expect(viewModel.showHelpAffordance == true)
    }

    // MARK: - Help Affordance: Reactive Updates

    /// VoiceOver toggled off mid-session → affordance appears without relaunching.
    @Test func stateChangeFromOnToOffShowsAffordance() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let viewModel = makeViewModel(isVoiceOverRunning: true, stateChanges: stream)

        #expect(viewModel.showHelpAffordance == false)

        continuation.yield(false)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms

        #expect(viewModel.showHelpAffordance == true)
        continuation.finish()
    }

    /// VoiceOver toggled on mid-session → affordance disappears without relaunching.
    @Test func stateChangeFromOffToOnHidesAffordance() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let viewModel = makeViewModel(isVoiceOverRunning: false, stateChanges: stream)

        #expect(viewModel.showHelpAffordance == true)

        continuation.yield(true)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(viewModel.showHelpAffordance == false)
        continuation.finish()
    }

    /// Rapid toggles converge to the final state — no race condition in the async stream handler.
    @Test func rapidTogglesConvergeToFinalState() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let viewModel = makeViewModel(isVoiceOverRunning: true, stateChanges: stream)

        continuation.yield(false)
        continuation.yield(true)
        continuation.yield(false) // final: VO off → affordance shown
        continuation.finish()

        try? await Task.sleep(nanoseconds: 20_000_000) // 20 ms

        #expect(viewModel.showHelpAffordance == true)
    }

    // MARK: - Best Results: Initial Load

    /// Unplayed games produce nil from `bestRank(for:)` — displayed as "Quest Awaits" in the hub.
    @Test func unplayedGamesHaveNilBestRank() async {
        let viewModel = makeViewModel(isVoiceOverRunning: true)
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(viewModel.bestRank(for: "find-and-focus") == nil)
        #expect(viewModel.bestRank(for: "activate-double-tap") == nil)
        #expect(viewModel.bestRank(for: "scroll-hunt") == nil)
    }

    /// Results stored before the view model is created are loaded on init.
    ///
    /// Validates the async init-time load — the view model must be ready before the
    /// first hub render populates the quest card rank badges.
    @Test func storedResultsLoadOnInit() async {
        let storage = InMemoryStorageComponent()
        let legendary = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8.0, mistakes: 0)
        let novice    = GameResult(gameID: "scroll-hunt",    rank: .ok,      timeSeconds: 40.0, mistakes: 2)
        await storage.saveResultIfBetter(legendary)
        await storage.saveResultIfBetter(novice)

        let viewModel = makeViewModel(isVoiceOverRunning: true, storage: storage)
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(viewModel.bestRank(for: "find-and-focus")      == .perfect)
        #expect(viewModel.bestRank(for: "activate-double-tap") == nil)
        #expect(viewModel.bestRank(for: "scroll-hunt")         == .ok)
    }

    // MARK: - Best Results: Refresh

    /// After a first play, `refreshBestResults()` reflects the new result without relaunch.
    @Test func refreshBestResultsReflectsNewlySavedResult() async {
        let storage   = InMemoryStorageComponent()
        let viewModel = makeViewModel(isVoiceOverRunning: true, storage: storage)
        try? await Task.sleep(nanoseconds: 20_000_000)

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

        let viewModel = makeViewModel(isVoiceOverRunning: true, storage: storage)
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(viewModel.bestRank(for: "find-and-focus") == .ok)

        let legendary = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 8, mistakes: 0)
        await storage.saveResultIfBetter(legendary)
        await viewModel.refreshBestResults()

        #expect(viewModel.bestRank(for: "find-and-focus") == .perfect)
    }

    /// An unknown game ID returns nil gracefully — no crash, no phantom data.
    @Test func bestRankForUnknownIDReturnsNil() async {
        let viewModel = makeViewModel(isVoiceOverRunning: true)
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(viewModel.bestRank(for: "nonexistent-game") == nil)
    }
}
