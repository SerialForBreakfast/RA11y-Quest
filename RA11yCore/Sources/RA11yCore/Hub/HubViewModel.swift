import Observation

// MARK: - HubViewModel

/// Observable view model driving the game hub screen.
///
/// Owns best-result data for all catalog games. VoiceOver state is intentionally
/// not observed here — the hub view reads `@Environment(\.accessibilityVoiceOverEnabled)`
/// directly, letting SwiftUI propagate state changes automatically without any custom
/// `AsyncStream` or `NotificationCenter` subscription.
///
/// `bestResults` is loaded via `refreshBestResults()`, which the hub view calls
/// from its `.task` modifier on every appearance (initial load and return from a game).
///
/// ## Concurrency
/// `@MainActor` isolation ensures all property mutations are serialized on the main
/// thread, consistent with SwiftUI's `@Observable` observation graph.
@Observable
@MainActor
public final class HubViewModel {

    // MARK: - Public State

    /// Best rank achieved per game ID, keyed by `GameDefinition.id`.
    ///
    /// An absent key means the game has not been played (displays "Quest Awaits").
    /// Populated by `refreshBestResults()`, which the hub view drives via `.task`.
    public private(set) var bestResults: [String: GameRank] = [:]

    // MARK: - Private

    private let storage: any StorageComponent

    // MARK: - Init

    /// Creates a view model backed by the given storage component.
    ///
    /// `bestResults` starts empty; call `refreshBestResults()` (or let the hub
    /// view's `.task` do so) to populate from storage.
    ///
    /// - Parameter storage: Persistence layer for best results. Inject
    ///   `UserDefaultsStorageComponent()` in production and
    ///   `InMemoryStorageComponent` in tests.
    public init(storage: any StorageComponent) {
        self.storage = storage
        RA11yLogger.startup.debug("HubViewModel.init")
    }

    // MARK: - Public API

    /// Best rank for the given game ID, or `nil` if the game has not been played.
    ///
    /// A `nil` result corresponds to "Quest Awaits" in the hub UI.
    ///
    /// - Parameter gameID: The stable `GameDefinition.id` (e.g. `"find-and-focus"`).
    public func bestRank(for gameID: String) -> GameRank? {
        bestResults[gameID]
    }

    /// Reloads best results from storage.
    ///
    /// Call this after a game session completes and the user returns to the hub,
    /// so that updated ranks are reflected without requiring an app relaunch.
    ///
    /// ## Concurrency
    /// `@MainActor` — safe to call from SwiftUI `.task` or `.onAppear`.
    /// Internally awaits `storage.bestResult(for:)` per game, hopping to the
    /// storage actor and back for each call.
    public func refreshBestResults() async {
        await loadBestResults()
    }

    // MARK: - Private

    /// Iterates all catalog games and loads their best result from storage.
    ///
    /// Runs on `@MainActor`; awaits the storage actor for each game read.
    /// Each `await` is a cross-actor hop to `UserDefaultsStorageComponent` and back.
    /// Writes `bestResults` atomically after all reads complete.
    ///
    /// ## Startup Instrumentation
    /// Emits a `hubResultsLoad` signpost interval covering all storage reads.
    /// If this interval is long, suspect sequential actor hops — consider batching
    /// reads into a single actor call on `StorageComponent` in a future refactor.
    private func loadBestResults() async {
        let state = RA11yLogger.startupSignposter.beginInterval("hubResultsLoad")
        defer { RA11yLogger.startupSignposter.endInterval("hubResultsLoad", state) }

        RA11yLogger.startup.debug("hubResultsLoad started — \(GameCatalog.all.count) games")

        var results: [String: GameRank] = [:]
        for game in GameCatalog.all {
            if let result = await storage.bestResult(for: game.id) {
                results[game.id] = result.rank
            }
        }
        bestResults = results

        RA11yLogger.startup.debug("hubResultsLoad complete — \(results.count) stored result(s)")
    }
}
