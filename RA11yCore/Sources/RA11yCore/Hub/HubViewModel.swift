import Observation

// MARK: - HubViewModel

/// Observable view model driving the game hub screen.
///
/// Exposes:
/// - `showHelpAffordance` — whether the "Enable VoiceOver" banner is visible.
///   Derived from live VoiceOver state via `VoiceOverStateProvider`.
/// - `bestResults` — a map of game ID → best `GameRank` for each played game.
///   Loaded asynchronously from `StorageComponent` on init; refreshable after a
///   game session completes via `refreshBestResults()`.
///
/// The hub view uses `if viewModel.showHelpAffordance { ... }` (not `.hidden()`)
/// to ensure the affordance is fully removed from the view hierarchy — and
/// therefore not focusable by VoiceOver — when VoiceOver is active.
///
/// ## Concurrency
/// `@MainActor` isolation ensures all property mutations are serialized on the
/// main thread, keeping the `@Observable` observation graph consistent with SwiftUI.
/// The VoiceOver observation task and the initial results-loading task are both
/// confined to `@MainActor`.
@Observable
@MainActor
public final class HubViewModel {

    // MARK: - Public State

    /// Whether the "How to enable VoiceOver" help affordance should be shown.
    ///
    /// `true` when VoiceOver is OFF — the user may need guidance to enable it.
    /// `false` when VoiceOver is ON — the affordance is removed from the hierarchy.
    public private(set) var showHelpAffordance: Bool

    /// Best rank achieved per game ID, keyed by `GameDefinition.id`.
    ///
    /// An absent key means the game has not been played (displays "Quest Awaits").
    /// Populated asynchronously on init; updated by calling `refreshBestResults()`.
    public private(set) var bestResults: [String: GameRank] = [:]

    // MARK: - Private

    private let storage: any StorageComponent

    /// `nonisolated(unsafe)` lets `deinit` call `cancel()` without actor-hopping.
    /// `Task.cancel()` is thread-safe; no data race is possible here.
    nonisolated(unsafe) private var stateObservationTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a view model subscribed to the given VoiceOver provider and storage.
    ///
    /// - `showHelpAffordance` is set synchronously from `provider.isVoiceOverRunning`.
    /// - Subsequent VoiceOver changes are delivered via `provider.stateChanges`.
    /// - `bestResults` is populated asynchronously from `storage` on init.
    ///
    /// - Parameters:
    ///   - voiceOverProvider: Source of VoiceOver state. Inject
    ///     `iOSLiveVoiceOverStateProvider()` in production and
    ///     `StubVoiceOverStateProvider` in tests.
    ///   - storage: Persistence layer for best results. Inject
    ///     `UserDefaultsStorageComponent()` in production and
    ///     `InMemoryStorageComponent` in tests.
    public init(voiceOverProvider: some VoiceOverStateProvider, storage: any StorageComponent) {
        self.storage = storage
        self.showHelpAffordance = !voiceOverProvider.isVoiceOverRunning

        stateObservationTask = Task { @MainActor [weak self] in
            for await isRunning in voiceOverProvider.stateChanges {
                self?.showHelpAffordance = !isRunning
            }
        }

        Task { @MainActor [weak self] in
            await self?.loadBestResults()
        }
    }

    deinit {
        stateObservationTask?.cancel()
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
    /// Writes `bestResults` atomically after all reads complete.
    private func loadBestResults() async {
        var results: [String: GameRank] = [:]
        for game in GameCatalog.all {
            if let result = await storage.bestResult(for: game.id) {
                results[game.id] = result.rank
            }
        }
        bestResults = results
    }
}
