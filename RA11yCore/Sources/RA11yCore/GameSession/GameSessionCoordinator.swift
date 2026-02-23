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

    deinit {
        Task { @MainActor [weak self] in
            self?.monitorTask?.cancel()
            self?.monitorTask = nil
        }
    }

    // MARK: - Monitoring Lifecycle

    /// Begins monitoring VoiceOver state changes for the active session.
    ///
    /// Call this when gameplay starts (e.g., in a SwiftUI `.task` modifier).
    /// The monitor is one-shot: once VoiceOver goes off mid-session, the task
    /// abandons the session and exits. If the session completes normally,
    /// `stopMonitoring()` or `deinit` cleans up the task.
    ///
    /// Idempotent — calling when already monitoring replaces the previous task.
    public func startMonitoring() {
        monitorTask?.cancel()

        monitorTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await isRunning in voiceOverProvider.stateChanges {
                guard !Task.isCancelled else { break }  // stopMonitoring() was called
                guard !isRunning else { continue }  // VO still on — keep watching

                let currentState = await session.state
                guard currentState == .running || currentState == .paused else {
                    break  // session already in a terminal state — nothing to do
                }

                await session.abandon()
                voiceOverDisabledMidGame = true
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
