import Foundation
import Testing
@testable import RA11yCore

// MARK: - GameSessionTests

/// Tests for `GameSession` state machine transitions, elapsed-time accounting,
/// mistake handling, and storage integration.
///
/// Validates TICKET-M1-GameSessionLifecycle acceptance criteria.
/// All time-sensitive assertions use injected `Date` values so there is no
/// dependency on wall-clock timing.
struct GameSessionTests {

    // MARK: - Helpers

    private func makeSession(storage: InMemoryStorageComponent = InMemoryStorageComponent()) -> GameSession {
        GameSession(gameID: "find-and-focus", thresholds: .findAndFocus, storage: storage)
    }

    // Fixed time points for deterministic elapsed-time assertions.
    private let t0  = Date(timeIntervalSinceReferenceDate: 0)
    private let t5  = Date(timeIntervalSinceReferenceDate: 5)
    private let t10 = Date(timeIntervalSinceReferenceDate: 10)
    private let t15 = Date(timeIntervalSinceReferenceDate: 15)
    private let t20 = Date(timeIntervalSinceReferenceDate: 20)
    private let t25 = Date(timeIntervalSinceReferenceDate: 25)
    private let t30 = Date(timeIntervalSinceReferenceDate: 30)
    private let t40 = Date(timeIntervalSinceReferenceDate: 40)
    private let t45 = Date(timeIntervalSinceReferenceDate: 45)

    // MARK: - Initial State

    @Test func initialStateIsIdle() async {
        let session = makeSession()
        #expect(await session.state == .idle)
    }

    // MARK: - Valid Transitions

    @Test func startTransitionsToRunning() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        #expect(await session.state == .running)
    }

    @Test func pauseTransitionsToPaused() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.pause(at: t10)
        #expect(await session.state == .paused)
    }

    @Test func resumeTransitionsToRunning() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.pause(at: t10)
        try await session.resume(at: t20)
        #expect(await session.state == .running)
    }

    // MARK: - Abandon

    /// Abandon from running → abandoned, no storage write.
    @Test func runningThenAbandonIsAbandoned() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        await session.abandon()

        #expect(await session.state == .abandoned)
        #expect(await storage.bestResult(for: "find-and-focus") == nil)
    }

    /// Abandon from paused → abandoned, no storage write.
    @Test func pauseThenAbandonIsAbandoned() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.pause(at: t10)
        await session.abandon()

        #expect(await session.state == .abandoned)
        #expect(await storage.bestResult(for: "find-and-focus") == nil)
    }

    /// Abandon from a terminal state (.completed) is silently ignored.
    @Test func abandonFromCompletedStateIsNoOp() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.complete(at: t10)

        await session.abandon()

        if case .completed = await session.state { } else {
            Issue.record("Expected .completed state — abandon must not change terminal state.")
        }
    }

    // MARK: - Complete + Storage

    /// Complete from running → writes result with correct elapsed time and rank.
    @Test func completedSessionWritesResultToStorage() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.complete(at: t10) // 10s, 0 mistakes → Perfect per findAndFocus thresholds

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored != nil)
        #expect(stored?.timeSeconds == 10)
        #expect(stored?.mistakes == 0)
        #expect(stored?.rank == .perfect)
    }

    // MARK: - Mistakes

    @Test func mistakeCountIncrementsCorrectly() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.recordMistake()
        try await session.recordMistake()
        #expect(await session.mistakeCount == 2)
    }

    /// Mistakes degrade the awarded rank on completion — end-to-end scoring contract.
    @Test func mistakeAffectsRankOnCompletion() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.recordMistake() // 1 mistake: 10s + 1 mistake → Good (not Perfect)
        try await session.complete(at: t10)

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored?.rank == .good)
    }

    // MARK: - Elapsed Time

    /// Single pause/resume: active time excludes the pause window.
    @Test func elapsedTimeAccountsForPauseDuration() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)   // start at 0
        try await session.pause(at: t10)  // 10s active
        try await session.resume(at: t20) // pause window = 10s (not counted)
        try await session.complete(at: t30) // 10s + 10s active = 20s total

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored?.timeSeconds == 20)
    }

    /// Multiple pause/resume cycles: only active periods sum into elapsed time.
    @Test func multiplePauseResumeAccumulatesElapsedTimeCorrectly() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        // Active: 0→5 = 5s, paused: 5→15 (10s gap, excluded)
        // Active: 15→20 = 5s, paused: 20→40 (20s gap, excluded)
        // Active: 40→45 = 5s → total active = 15s
        try await session.start(at: t0)
        try await session.pause(at: t5)
        try await session.resume(at: t15)
        try await session.pause(at: t20)
        try await session.resume(at: t40)
        try await session.complete(at: t45)

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored?.timeSeconds == 15)
    }

    // MARK: - Invalid Transitions

    @Test func startTwiceThrows() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        await #expect(throws: GameSessionError.self) {
            try await session.start(at: self.t10)
        }
    }

    @Test func pauseFromIdleThrows() async {
        let session = makeSession()
        await #expect(throws: GameSessionError.self) {
            try await session.pause(at: self.t0)
        }
    }

    /// Cannot complete a paused session — must resume to running first.
    @Test func completeFromPausedThrows() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.pause(at: t10)
        await #expect(throws: GameSessionError.self) {
            try await session.complete(at: self.t20)
        }
    }

    // MARK: - Full-Screen Exit (M8 Contract)

    /// Validates TICKET-M8 acceptance criterion: "Leaving full-screen stops gameplay
    /// and does not write a result."
    ///
    /// The view layer calls `handleViewDisappear()` → `session.abandon()`.
    /// This test verifies the resulting state is `.abandoned` and storage is untouched.
    @Test func fullScreenExitedFromRunningTransitionsToAbandonedWithNoStorageWrite() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        // Simulate the user backing out of a running L3 game via navigation.
        await session.abandon()

        #expect(await session.state == .abandoned)
        #expect(await storage.bestResult(for: "find-and-focus") == nil,
                "Back-navigation must not write a result to storage.")
    }

    /// Validates that full-screen exit after a completed game does not overwrite the result.
    ///
    /// A completed session is in a terminal state — `abandon()` is a no-op per the state
    /// machine contract. The stored result must remain intact.
    @Test func fullScreenExitedAfterCompletionDoesNotEraseResult() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.complete(at: t10) // 10s, 0 mistakes → Perfect
        // Simulate a delayed back-navigation after result is already written.
        await session.abandon()

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored != nil, "Completed result must persist after a no-op abandon.")
        #expect(stored?.rank == .perfect)
    }
}
