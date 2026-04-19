import Observation

// MARK: - GameSessionCoordinator

/// Observable coordinator that bridges VoiceOver state changes into `GameSession` lifecycle.
///
/// Monitors `VoiceOverStateProvider.stateChanges` while a game session is active.
/// If VoiceOver transitions OFF during a running or paused session:
/// - The session is transitioned to `.abandoned` (no storage write).
/// - `voiceOverDisabledMidGame` is set to `true` for the game view to observe
///   and navigate to `AppRoute.voiceOverInterstitial(kind:)`.
///
/// ## Usage (M5+)
/// Game views create a `GameSessionCoordinator`, call `startMonitoring()` when
/// gameplay begins, and observe `voiceOverDisabledMidGame` to trigger interstitial
/// navigation. `stopMonitoring()` (or `deinit`) cleans up the internal task.
///
/// ```swift
/// .task {
///     await coordinator.startMonitoring()
/// }
/// .onChange(of: coordinator.voiceOverDisabledMidGame) { _, disabled in
///     if disabled { router.push(.voiceOverInterstitial(kind: gameKind)) }
/// }
/// ```
///
/// ## Concurrency
/// `@MainActor` isolation keeps `voiceOverDisabledMidGame` mutations on the main
/// thread, consistent with SwiftUI observation. The internal monitoring `Task` is
/// also confined to `@MainActor`.
@Observable
@MainActor
public final class GameSessionCoordinator {

    // MARK: - Public State

    /// The game session whose lifecycle this coordinator manages.
    public let session: GameSession

    /// The catalog kind of the game being played.
    ///
    /// Carried so the view can pass the correct `kind` to
    /// `AppRoute.voiceOverInterstitial(kind:)` on navigation.
    public let gameKind: GameKind

    /// Set to `true` when VoiceOver is disabled while the session is active.
    ///
    /// Game views observe this property and push `.voiceOverInterstitial(kind: gameKind)`
    /// onto the navigation stack when it becomes `true`.
    public private(set) var voiceOverDisabledMidGame = false

    // MARK: - Private

    private let voiceOverProvider: any VoiceOverStateProvider

    /// Task that observes VoiceOver state changes during an active session.
    ///
    /// Plain stored property — no isolation modifier required. The monitoring closure
    /// captures `[weak self]` and re-checks `self` inside the `for await` loop so the
    /// running Task does not retain the coordinator. `stopMonitoring()` provides eager
    /// cancellation when the session completes normally.
    private var monitorTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a coordinator for the given session, game kind, and VoiceOver provider.
    ///
    /// - Parameters:
    ///   - session: The active `GameSession` to monitor and potentially abandon.
    ///   - gameKind: The catalog kind; carried to the interstitial route on VO-off.
    ///   - voiceOverProvider: Source of VoiceOver state changes. Inject
    ///     `iOSLiveVoiceOverStateProvider()` in production and
    ///     `StubVoiceOverStateProvider` in tests.
    public init(
        session: GameSession,
        gameKind: GameKind,
        voiceOverProvider: some VoiceOverStateProvider
    ) {
        self.session          = session
        self.gameKind         = gameKind
        self.voiceOverProvider = voiceOverProvider
    }

    // MARK: - Monitoring Lifecycle

    /// Begins monitoring VoiceOver state changes for the active session.
    ///
    /// Call this when gameplay starts (e.g., directly after `session.start()`).
    /// The monitor is one-shot: once VoiceOver goes off mid-session the task
    /// abandons the session and exits. If the session completes normally,
    /// `stopMonitoring()` cleans up the task.
    ///
    /// The closure captures `[weak self]` and re-evaluates `self` on each loop
    /// iteration to avoid retaining the coordinator for the lifetime of the task.
    /// `voiceOverProvider` is captured strongly by value so the sequence remains
    /// live even if the coordinator is released between iterations.
    ///
    /// Idempotent — calling when already monitoring replaces the previous task.
    public func startMonitoring() {
        monitorTask?.cancel()

        monitorTask = Task { @MainActor [weak self, provider = voiceOverProvider] in
            for await isRunning in provider.stateChanges {
                // Re-acquire self and check cancellation on every event.
                // If the coordinator was released or stopMonitoring() was called, exit.
                guard let self, !Task.isCancelled else { return }
                guard !isRunning else { continue }  // VO still on — keep watching

                let currentState = await self.session.state
                guard currentState == .running || currentState == .paused else {
                    break  // session already in a terminal state — nothing to do
                }

                await self.session.abandon()
                self.voiceOverDisabledMidGame = true
                RA11yLogger.voiceOver.info("VoiceOver disabled mid-session for \(self.gameKind.rawValue); session abandoned.")
                break  // one-shot: exit after handling the event
            }
        }
    }

    /// Stops monitoring VoiceOver state changes.
    ///
    /// Call this when the game view disappears or when the session reaches a
    /// terminal state via normal completion (not VO-off abandonment).
    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }
}
