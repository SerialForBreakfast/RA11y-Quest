@testable import RA11yCore

// MARK: - InMemoryStorageComponent

/// In-memory `StorageComponent` for use in unit tests.
///
/// Serializes state on the actor's executor, matching the concurrency semantics
/// of `UserDefaultsStorageComponent` without persisting to disk.
actor InMemoryStorageComponent: StorageComponent {

    private var results: [String: GameResult] = [:]
    private var _basicsCompleted = false
    private var _basicsDismissed = false

    /// Returns the best stored result for the given game ID, if any.
    func bestResult(for gameID: String) async -> GameResult? {
        results[gameID]
    }

    /// Saves the result when it improves on the current best result.
    func saveResultIfBetter(_ result: GameResult) async {
        let existing = results[result.gameID]
        if let existing, !result.isBetter(than: existing) { return }
        results[result.gameID] = result
    }

    /// Returns whether the Basics sequence has been completed.
    func isBasicsCompleted() async -> Bool {
        _basicsCompleted
    }

    /// Returns both Basics flags in one read for startup routing tests.
    func basicsProgressSnapshot() async -> BasicsProgressSnapshot {
        BasicsProgressSnapshot(isCompleted: _basicsCompleted, isDismissed: _basicsDismissed)
    }

    /// Marks the Basics sequence as completed.
    func markBasicsCompleted() async {
        _basicsCompleted = true
    }

    /// Returns whether the Basics sequence was dismissed.
    func isBasicsDismissed() async -> Bool {
        _basicsDismissed
    }

    /// Returns best stored results for the requested game IDs.
    func bestResults(for gameIDs: [String]) async -> [String : GameResult] {
        Dictionary(uniqueKeysWithValues: gameIDs.compactMap { id in
            guard let result = results[id] else { return nil }
            return (id, result)
        })
    }

    /// Marks the Basics sequence as dismissed.
    func markBasicsDismissed() async {
        _basicsDismissed = true
    }
}
