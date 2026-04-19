import Testing
@testable import RA11yCore

// MARK: - StorageTests

/// Tests for `StorageComponent` protocol semantics using `InMemoryStorageComponent`.
///
/// Validates TICKET-M1-StorageComponent-UserDefaults acceptance criteria.
struct StorageTests {

    // MARK: - Read / Write

    @Test func saveAndRetrieveBestResult() async {
        let storage = InMemoryStorageComponent()
        let result  = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 10, mistakes: 0)

        await storage.saveResultIfBetter(result)

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored == result)
    }

    @Test func returnsNilForUnplayedGame() async {
        let storage = InMemoryStorageComponent()
        let stored  = await storage.bestResult(for: "never-played")
        #expect(stored == nil)
    }

    // MARK: - Best-Result Semantics

    /// A worse result must not replace the stored best.
    @Test func doesNotOverwriteBetterResultWithWorse() async {
        let storage = InMemoryStorageComponent()
        let better  = GameResult(gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0)
        let worse   = GameResult(gameID: "g", rank: .good,    timeSeconds: 15, mistakes: 1)

        await storage.saveResultIfBetter(better)
        await storage.saveResultIfBetter(worse)

        let stored = await storage.bestResult(for: "g")
        #expect(stored?.rank == .perfect)
    }

    /// A better result must replace the previously stored one.
    @Test func overwritesWithBetterResult() async {
        let storage = InMemoryStorageComponent()
        let initial = GameResult(gameID: "g", rank: .good,    timeSeconds: 20, mistakes: 2)
        let better  = GameResult(gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0)

        await storage.saveResultIfBetter(initial)
        await storage.saveResultIfBetter(better)

        let stored = await storage.bestResult(for: "g")
        #expect(stored?.rank == .perfect)
    }

    // MARK: - Key Isolation

    /// Saving a result for game A must not affect game B.
    ///
    /// Critical: verifies that results are keyed by game ID, not shared state.
    @Test func resultsForDifferentGamesAreIsolated() async {
        let storage = InMemoryStorageComponent()
        let result  = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 10, mistakes: 0)

        await storage.saveResultIfBetter(result)

        let other = await storage.bestResult(for: "activate-double-tap")
        #expect(other == nil)
    }

    // MARK: - Basics Flag

    @Test func basicsCompletedFlagPersists() async {
        let storage = InMemoryStorageComponent()
        #expect(await storage.isBasicsCompleted() == false)

        await storage.markBasicsCompleted()

        #expect(await storage.isBasicsCompleted() == true)
    }

    /// Basics flag for one storage instance must not affect a separate instance.
    ///
    /// Validates that `InMemoryStorageComponent` does not share state between instances.
    @Test func basicsCompletedFlagIsInstanceIsolated() async {
        let a = InMemoryStorageComponent()
        let b = InMemoryStorageComponent()

        await a.markBasicsCompleted()

        #expect(await b.isBasicsCompleted() == false)
    }

    @Test func basicsDismissedFlagPersists() async {
        let storage = InMemoryStorageComponent()
        #expect(await storage.isBasicsDismissed() == false)

        await storage.markBasicsDismissed()

        #expect(await storage.isBasicsDismissed() == true)
    }

    /// Dismissed flag for one storage instance must not affect a separate instance.
    ///
    /// Validates that `InMemoryStorageComponent` does not share dismissal state.
    @Test func basicsDismissedFlagIsInstanceIsolated() async {
        let a = InMemoryStorageComponent()
        let b = InMemoryStorageComponent()

        await a.markBasicsDismissed()

        #expect(await b.isBasicsDismissed() == false)
    }
}
