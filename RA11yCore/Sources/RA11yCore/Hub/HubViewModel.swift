import Observation

// MARK: - HubViewModel

/// Observable view model driving the game hub screen.
///
/// Derives `showHelpAffordance` from live VoiceOver state and keeps it current
/// by subscribing to `VoiceOverStateProvider.stateChanges` for the lifetime of
/// the view model.
///
/// The hub view uses `if viewModel.showHelpAffordance { ... }` (not `.hidden()`)
/// to ensure the affordance is fully removed from the view hierarchy — and
/// therefore not focusable by VoiceOver — when VoiceOver is active.
///
/// ## M3 Extension Point
/// `startGame(kind:)` and catalog / best-result properties will be added in M3
/// when the full hub UI is implemented.
///
/// ## Concurrency
/// `@MainActor` isolation ensures all property mutations are serialized on the
/// main thread, keeping the `@Observable` observation graph consistent with SwiftUI.
/// The internal `Task` that consumes `stateChanges` is also confined to `@MainActor`.
@Observable
@MainActor
public final class HubViewModel {

    // MARK: - Public State

    /// Whether the "How to enable VoiceOver" help affordance should be shown.
    ///
    /// `true` when VoiceOver is OFF — the user may need guidance to enable it.
    /// `false` when VoiceOver is ON — the affordance is removed from the hierarchy.
    public private(set) var showHelpAffordance: Bool

    // MARK: - Private

    /// `nonisolated(unsafe)` lets `deinit` call `cancel()` without actor-hopping.
    /// `Task.cancel()` is thread-safe; no data race is possible here.
    nonisolated(unsafe) private var stateObservationTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a view model subscribed to the given VoiceOver state provider.
    ///
    /// The initial value of `showHelpAffordance` is set synchronously from
    /// `provider.isVoiceOverRunning`; subsequent changes are delivered via
    /// `provider.stateChanges`.
    ///
    /// - Parameter voiceOverProvider: Source of VoiceOver state. Inject
    ///   `iOSLiveVoiceOverStateProvider()` in production and
    ///   `StubVoiceOverStateProvider` in tests.
    public init(voiceOverProvider: some VoiceOverStateProvider) {
        self.showHelpAffordance = !voiceOverProvider.isVoiceOverRunning

        stateObservationTask = Task { @MainActor [weak self] in
            for await isRunning in voiceOverProvider.stateChanges {
                self?.showHelpAffordance = !isRunning
            }
        }
    }

    deinit {
        stateObservationTask?.cancel()
    }
}
