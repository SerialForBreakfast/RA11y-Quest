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

    /// When `true`, every catalog game is treated as unlocked regardless of ``bestResults``.
    ///
    /// Used only for **local audit** (e.g. skipping prerequisite clears on a dev build) without
    /// farming prerequisites. The iOS host enables this in **DEBUG** via launch argument
    /// `-unlockAllQuestsForAudit` (Xcode → Scheme → Run → Arguments). Release builds
    /// must always pass `false`.
    private let unlockAllQuestsForAudit: Bool

    // MARK: - Init

    /// Creates a view model backed by the given storage component.
    ///
    /// `bestResults` starts empty; call `refreshBestResults()` (or let the hub
    /// view's `.task` do so) to populate from storage.
    ///
    /// - Parameters:
    ///   - storage: Persistence layer for best results. Inject
    ///     `UserDefaultsStorageComponent()` in production and
    ///     `InMemoryStorageComponent` in tests.
    ///   - unlockAllQuestsForAudit: Bypass prerequisite gating for QA/design audits.
    ///     Defaults to `false`; the iOS app sets this from a DEBUG launch flag only.
    public init(storage: any StorageComponent, unlockAllQuestsForAudit: Bool = false) {
        self.storage = storage
        self.unlockAllQuestsForAudit = unlockAllQuestsForAudit
        RA11yLogger.startup.debug("HubViewModel.init unlockAllQuestsForAudit=\(unlockAllQuestsForAudit)")
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

    /// Whether the given game is unlocked and available to start.
    ///
    /// A game with no `prerequisiteID` is always unlocked. A game with a prerequisite
    /// is unlocked as soon as the prerequisite has been completed at any rank.
    ///
    /// The hub uses this to render locked cards for games the player has not yet
    /// earned access to, enforcing the pedagogical sequence.
    ///
    /// - Parameter game: The `GameDefinition` to evaluate.
    /// - Returns: `true` if the game can be started.
    public func isUnlocked(_ game: GameDefinition) -> Bool {
        if unlockAllQuestsForAudit { return true }
        guard let prerequisiteID = game.prerequisiteID else { return true }
        return bestResults[prerequisiteID] != nil
    }

    /// The `GameDefinition` whose completion would unlock `game`, or `nil` if `game`
    /// is already unlocked or has no prerequisite.
    ///
    /// Used by the hub to display "Complete [prerequisite title] to unlock" messaging.
    ///
    /// - Parameter game: The locked game.
    /// - Returns: The predecessor `GameDefinition`, or `nil`.
    public func prerequisite(for game: GameDefinition) -> GameDefinition? {
        guard let prerequisiteID = game.prerequisiteID, !isUnlocked(game) else { return nil }
        return GameCatalog.definition(for: prerequisiteID)
    }

    /// Reloads best results from storage.
    ///
    /// Call this after a game session completes and the user returns to the hub,
    /// so that updated ranks are reflected without requiring an app relaunch.
    ///
    /// ## Concurrency
    /// `@MainActor` — safe to call from SwiftUI `.task` or `.onAppear`.
    /// Internally uses `storage.bestResults(for:)` so the hub refresh pays one
    /// storage hop for the whole catalog instead of one hop per game.
    public func refreshBestResults() async {
        await loadBestResults()
    }

    // MARK: - Private

    /// Iterates all catalog games and loads their best result from storage.
    ///
    /// Runs on `@MainActor`; awaits the storage actor once for the whole catalog and
    /// writes `bestResults` atomically after the batch read completes.
    ///
    /// ## Startup Instrumentation
    /// Emits a `hubResultsLoad` signpost interval covering all storage reads.
    /// If this interval is long, suspect sequential actor hops — consider batching
    /// reads into a single actor call on `StorageComponent` in a future refactor.
    private func loadBestResults() async {
        let state = RA11yLogger.startupSignposter.beginInterval("hubResultsLoad")
        defer { RA11yLogger.startupSignposter.endInterval("hubResultsLoad", state) }

        RA11yLogger.startup.debug("hubResultsLoad started — \(GameCatalog.all.count) games")

        let storedResults = await storage.bestResults(for: GameCatalog.all.map(\.id))

        var results: [String: GameRank] = [:]
        results.reserveCapacity(storedResults.count)
        for (gameID, result) in storedResults {
            results[gameID] = result.rank
        }
        bestResults = results

        RA11yLogger.startup.debug("hubResultsLoad complete — \(results.count) stored result(s)")
    }
}
