@testable import RA11yCore

// MARK: - InMemoryStorageComponent

/// In-memory `StorageComponent` for use in unit tests.
///
/// Serializes state on the actor's executor, matching the concurrency semantics
/// of `UserDefaultsStorageComponent` without persisting to disk.
actor InMemoryStorageComponent: StorageComponent {

    private var results: [String: GameResult] = [:]
    private var _basicsCompleted = false

    func bestResult(for gameID: String) async -> GameResult? {
        results[gameID]
    }

    func saveResultIfBetter(_ result: GameResult) async {
        let existing = results[result.gameID]
        if let existing, !result.isBetter(than: existing) { return }
        results[result.gameID] = result
    }

    func isBasicsCompleted() async -> Bool {
        _basicsCompleted
    }

    func markBasicsCompleted() async {
        _basicsCompleted = true
    }
}
