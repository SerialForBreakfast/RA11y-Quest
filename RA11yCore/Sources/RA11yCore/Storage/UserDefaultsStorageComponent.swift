import Foundation

// MARK: - UserDefaultsStorageComponent

/// `StorageComponent` backed by `UserDefaults`.
///
/// All state access is serialized on the actor's executor, ensuring
/// thread-safe reads and writes without requiring `@unchecked Sendable`.
///
/// ## Storage Keys
/// Keys are namespaced under `com.ra11y.storage` to prevent collisions with
/// other defaults. Key format: `com.ra11y.storage.<gameID>.bestResult`.
///
/// ## Future Migration
/// Replacing this with a SwiftData-backed implementation requires only a new
/// `StorageComponent` conformance — no call-site changes are needed.
public actor UserDefaultsStorageComponent: StorageComponent {

    // MARK: - Private

    private let defaults: UserDefaults
    private static let keyPrefix    = "com.ra11y.storage."
    private static let basicsKey    = "\(keyPrefix)basicsCompleted"
    private static let dismissedKey = "\(keyPrefix)basicsDismissed"

    // MARK: - Init

    /// Creates a component using the given `UserDefaults` instance.
    ///
    /// - Parameter defaults: Defaults to `UserDefaults.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - StorageComponent

    /// Returns the best stored result for the given game ID, if present.
    public func bestResult(for gameID: String) async -> GameResult? {
        _bestResult(for: gameID)
    }

    /// Saves the result if it improves on the stored best result.
    public func saveResultIfBetter(_ result: GameResult) async {
        let existing = _bestResult(for: result.gameID)
        if let existing, !result.isBetter(than: existing) { return }

        guard let data = try? JSONEncoder().encode(result) else {
            RA11yLogger.storage.error("Encode failed for gameID: \(result.gameID)")
            return
        }
        defaults.set(data, forKey: _storageKey(for: result.gameID))
        RA11yLogger.storage.debug("Saved best result — \(result.gameID): \(result.rank.displayText)")
    }

    /// Returns whether the Basics sequence has been completed.
    public func isBasicsCompleted() async -> Bool {
        defaults.bool(forKey: Self.basicsKey)
    }

    /// Returns both Basics flags in one actor-isolated read.
    public func basicsProgressSnapshot() async -> BasicsProgressSnapshot {
        BasicsProgressSnapshot(
            isCompleted: defaults.bool(forKey: Self.basicsKey),
            isDismissed: defaults.bool(forKey: Self.dismissedKey)
        )
    }

    /// Marks the Basics sequence as completed in UserDefaults.
    public func markBasicsCompleted() async {
        defaults.set(true, forKey: Self.basicsKey)
        RA11yLogger.storage.info("Basics sequence marked as completed.")
    }

    /// Returns whether the Basics sequence was dismissed.
    public func isBasicsDismissed() async -> Bool {
        defaults.bool(forKey: Self.dismissedKey)
    }

    /// Returns best results for all requested game IDs in one actor call.
    public func bestResults(for gameIDs: [String]) async -> [String: GameResult] {
        var results: [String: GameResult] = [:]
        results.reserveCapacity(gameIDs.count)
        for gameID in gameIDs {
            if let result = _bestResult(for: gameID) {
                results[gameID] = result
            }
        }
        return results
    }

    /// Marks the Basics sequence as dismissed in UserDefaults.
    public func markBasicsDismissed() async {
        defaults.set(true, forKey: Self.dismissedKey)
        RA11yLogger.storage.info("Basics sequence marked as dismissed.")
    }

    // MARK: - Private Helpers

    /// Synchronous read used internally to avoid cross-actor hops within the same actor.
    private func _bestResult(for gameID: String) -> GameResult? {
        guard let data = defaults.data(forKey: _storageKey(for: gameID)) else { return nil }
        return try? JSONDecoder().decode(GameResult.self, from: data)
    }

    private func _storageKey(for gameID: String) -> String {
        "\(Self.keyPrefix)\(gameID).bestResult"
    }
}

// MARK: - Screenshot Testing Support

#if DEBUG
public extension UserDefaultsStorageComponent {

    /// Keys exposed for the screenshot automation reset handler in `RA11y_iOSApp`.
    ///
    /// - Warning: Use only from the `-screenshotResetOnboarding` launch argument
    ///   handler. Never call from production paths.
    enum ScreenshotTestingKeys {
        /// Key for the "basics completed" flag. Mirrors `UserDefaultsStorageComponent.basicsKey`.
        public static let basicsCompleted = UserDefaultsStorageComponent.basicsKey
        /// Key for the "basics dismissed" flag. Mirrors `UserDefaultsStorageComponent.dismissedKey`.
        public static let basicsDismissed = UserDefaultsStorageComponent.dismissedKey
    }
}
#endif
