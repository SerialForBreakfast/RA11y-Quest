import Testing
@testable import RA11yCore

// MARK: - StorageTests

/// Tests for `StorageComponent` protocol semantics using `InMemoryStorageComponent`.
///
/// Validates TICKET-M1-StorageComponent-UserDefaults acceptance criteria.
struct StorageTests {

    @Test func saveAndRetrieveBestResult() async {
        let storage = InMemoryStorageComponent()
        let result  = GameResult(gameID: "find-and-focus", rank: .perfect, timeSeconds: 10, mistakes: 0)

        await storage.saveResultIfBetter(result)

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored == result)
    }

    @Test func doesNotOverwriteBetterResultWithWorse() async {
        let storage = InMemoryStorageComponent()
        let better  = GameResult(gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0)
        let worse   = GameResult(gameID: "g", rank: .good,    timeSeconds: 15, mistakes: 1)

        await storage.saveResultIfBetter(better)
        await storage.saveResultIfBetter(worse)

        let stored = await storage.bestResult(for: "g")
        #expect(stored?.rank == .perfect)
    }

    @Test func overwritesWithBetterResult() async {
        let storage = InMemoryStorageComponent()
        let initial = GameResult(gameID: "g", rank: .good,    timeSeconds: 20, mistakes: 2)
        let better  = GameResult(gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0)

        await storage.saveResultIfBetter(initial)
        await storage.saveResultIfBetter(better)

        let stored = await storage.bestResult(for: "g")
        #expect(stored?.rank == .perfect)
    }

    @Test func returnsNilForUnplayedGame() async {
        let storage = InMemoryStorageComponent()
        let stored  = await storage.bestResult(for: "never-played")
        #expect(stored == nil)
    }

    @Test func basicsCompletedFlagPersists() async {
        let storage = InMemoryStorageComponent()
        #expect(await storage.isBasicsCompleted() == false)

        await storage.markBasicsCompleted()

        #expect(await storage.isBasicsCompleted() == true)
    }
}
