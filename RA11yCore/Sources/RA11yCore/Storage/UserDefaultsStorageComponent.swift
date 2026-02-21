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

    // MARK: - Init

    /// Creates a component using the given `UserDefaults` instance.
    ///
    /// - Parameter defaults: Defaults to `UserDefaults.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - StorageComponent

    public func bestResult(for gameID: String) async -> GameResult? {
        _bestResult(for: gameID)
    }

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

    public func isBasicsCompleted() async -> Bool {
        defaults.bool(forKey: Self.basicsKey)
    }

    public func markBasicsCompleted() async {
        defaults.set(true, forKey: Self.basicsKey)
        RA11yLogger.storage.info("Basics sequence marked as completed.")
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
