import Foundation

// MARK: - GameSession

/// Actor-isolated state machine managing the full lifecycle of a single training game session.
///
/// ## State Machine
///
/// ```
/// idle ──start──▶ running ──pause──▶ paused
///                    │                  │
///                complete            resume──▶ running
///                    │                  │
///                    ▼               abandon
///               completed(result)       │
///                                       ▼
///                                   abandoned
/// ```
///
/// - `complete` transitions from `running` → `completed` and writes the result to storage.
/// - `abandon` transitions from `running` or `paused` → `abandoned` with no storage write.
///
/// ## Concurrency
/// All methods execute on the actor's executor. Callers from `@MainActor` context must use `await`.
/// `storage` is a `Sendable` protocol type; cross-actor calls in `complete()` are safe.
///
/// ## Testability
/// No `UIApplication`, `Timer`, or global-singleton dependencies are used.
/// Inject `Date` values via method parameters to control time in tests.
public actor GameSession {

    // MARK: - Public State

    /// Current lifecycle state of the session.
    ///
    /// Observe this from the view layer to drive navigation (e.g., push result screen on `.completed`).
    public private(set) var state: GameSessionState = .idle

    /// Cumulative mistake count for the session. Incremented by `recordMistake()`.
    public private(set) var mistakeCount: Int = 0

    // MARK: - Private

    private let gameID: String
    private let thresholds: RankThresholds
    private let storage: any StorageComponent

    /// The `Date` at which the current running period began.
    private var runStartDate: Date?

    /// Accumulated active time from all completed running periods (excludes current period).
    private var elapsedBeforePause: TimeInterval = 0

    // MARK: - Init

    /// Creates a session for the given game with configured thresholds and a storage backend.
    ///
    /// - Parameters:
    ///   - gameID: Stable catalog ID matching `GameDefinition.id`.
    ///   - thresholds: Rank thresholds for this game (use `RankThresholds.<game>` presets).
    ///   - storage: Persistence backend. Injected for testability.
    public init(
        gameID: String,
        thresholds: RankThresholds,
        storage: any StorageComponent
    ) {
        self.gameID = gameID
        self.thresholds = thresholds
        self.storage = storage
    }

    // MARK: - Transitions

    /// Transitions from `idle` to `running`.
    ///
    /// - Parameter date: The logical start time. Defaults to `Date()` for production use.
    /// - Throws: `GameSessionError.invalidTransition` if not currently `.idle`.
    public func start(at date: Date = Date()) throws {
        guard state == .idle else {
            throw GameSessionError.invalidTransition(current: "\(state)", requested: "start")
        }
        runStartDate = date
        state = .running
        RA11yLogger.gameSession.debug("Session started — \(self.gameID)")
    }

    /// Transitions from `running` to `paused`. Preserves elapsed time.
    ///
    /// - Parameter date: The logical pause time. Defaults to `Date()`.
    /// - Throws: `GameSessionError.invalidTransition` if not currently `.running`.
    public func pause(at date: Date = Date()) throws {
        guard state == .running else {
            throw GameSessionError.invalidTransition(current: "\(state)", requested: "pause")
        }
        elapsedBeforePause += date.timeIntervalSince(runStartDate ?? date)
        runStartDate = nil
        state = .paused
        RA11yLogger.gameSession.debug("Session paused — \(self.gameID), elapsed: \(self.elapsedBeforePause)s")
    }

    /// Transitions from `paused` to `running`. Resumes time accumulation.
    ///
    /// - Parameter date: The logical resume time. Defaults to `Date()`.
    /// - Throws: `GameSessionError.invalidTransition` if not currently `.paused`.
    public func resume(at date: Date = Date()) throws {
        guard state == .paused else {
            throw GameSessionError.invalidTransition(current: "\(state)", requested: "resume")
        }
        runStartDate = date
        state = .running
        RA11yLogger.gameSession.debug("Session resumed — \(self.gameID)")
    }

    /// Transitions from `running` to `completed`, evaluates the result, and writes to storage.
    ///
    /// Only `.completed` sessions trigger a storage write. If the result is not better than
    /// the existing best, `saveResultIfBetter` is a no-op.
    ///
    /// - Parameter date: The logical completion time. Defaults to `Date()`.
    /// - Throws: `GameSessionError.invalidTransition` if not currently `.running`.
    ///
    /// ## Concurrency
    /// This method is `async` because it `await`s the cross-actor storage call.
    public func complete(at date: Date = Date()) async throws {
        guard state == .running else {
            let desc = String(describing: self.state)
            RA11yLogger.gameSession.error("Session complete rejected — \(self.gameID) state=\(desc, privacy: .public)")
            throw GameSessionError.invalidTransition(current: desc, requested: "complete")
        }
        let elapsed = _elapsedTime(at: date)
        let rank    = thresholds.evaluate(timeSeconds: elapsed, mistakes: mistakeCount)
        let result  = GameResult(gameID: gameID, rank: rank, timeSeconds: elapsed, mistakes: mistakeCount)
        state = .completed(result)
        await storage.saveResultIfBetter(result)
        RA11yLogger.gameSession.info("Session completed — \(self.gameID): \(rank.displayText) in \(elapsed)s with \(self.mistakeCount) mistake(s)")
    }

    /// Transitions from `running` or `paused` to `abandoned`. No storage write occurs.
    ///
    /// Safe to call in any non-terminal state; silently ignores calls from terminal states.
    ///
    /// ## Concurrency
    /// Marked `async` for uniform call-site ergonomics with `complete()` at the view/coordinator layer.
    public func abandon() async {
        let prior = self.state
        guard state == .running || state == .paused else {
            RA11yLogger.gameSession.debug("Session abandon no-op — \(self.gameID) state=\(String(describing: prior), privacy: .public)")
            return
        }
        state = .abandoned
        RA11yLogger.gameSession.info("Session abandoned — \(self.gameID) (was running or paused)")
    }

    /// Records a mistake. Only valid while `.running`.
    ///
    /// - Throws: `GameSessionError.invalidTransition` if not currently `.running`.
    public func recordMistake() throws {
        guard state == .running else {
            throw GameSessionError.invalidTransition(current: "\(state)", requested: "recordMistake")
        }
        mistakeCount += 1
        RA11yLogger.gameSession.debug("Mistake recorded — \(self.gameID): \(self.mistakeCount) total")
    }

    // MARK: - Private Helpers

    /// Computes total active elapsed time up to `date`, including all prior running periods.
    private func _elapsedTime(at date: Date) -> TimeInterval {
        elapsedBeforePause + (runStartDate.map { date.timeIntervalSince($0) } ?? 0)
    }
}
