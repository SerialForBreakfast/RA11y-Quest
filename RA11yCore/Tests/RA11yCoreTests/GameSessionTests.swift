import Foundation
import Testing
@testable import RA11yCore

// MARK: - GameSessionTests

/// Tests for `GameSession` state machine transitions and storage integration.
///
/// Validates TICKET-M1-GameSessionLifecycle acceptance criteria.
/// Uses fixed `Date` values to make elapsed-time assertions deterministic.
struct GameSessionTests {

    // MARK: - Helpers

    private func makeSession(storage: InMemoryStorageComponent = InMemoryStorageComponent()) -> GameSession {
        GameSession(gameID: "find-and-focus", thresholds: .findAndFocus, storage: storage)
    }

    private let t0 = Date(timeIntervalSinceReferenceDate: 0)
    private var t10: Date { Date(timeIntervalSinceReferenceDate: 10) }
    private var t20: Date { Date(timeIntervalSinceReferenceDate: 20) }
    private var t30: Date { Date(timeIntervalSinceReferenceDate: 30) }

    // MARK: - Basic Transitions

    @Test func initialStateIsIdle() async {
        let session = makeSession()
        #expect(await session.state == .idle)
    }

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

    /// TICKET-M1-GameSessionLifecycle: paused then abandoned → `.abandoned`, no storage write.
    @Test func pauseThenAbandonIsAbandoned() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.pause(at: t10)
        await session.abandon()

        #expect(await session.state == .abandoned)
        #expect(await storage.bestResult(for: "find-and-focus") == nil)
    }

    @Test func runningThenAbandonIsAbandoned() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        await session.abandon()

        #expect(await session.state == .abandoned)
        #expect(await storage.bestResult(for: "find-and-focus") == nil)
    }

    @Test func abandonFromTerminalStateIsNoOp() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.complete(at: t10)
        // Calling abandon on a completed session should silently do nothing.
        await session.abandon()
        // State remains completed (with some result)
        if case .completed = await session.state { } else {
            Issue.record("Expected .completed state after complete()")
        }
    }

    // MARK: - Complete + Storage

    /// TICKET-M1-GameSessionLifecycle: completed session writes result matching elapsed time and mistakes.
    @Test func completedSessionWritesResultToStorage() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.complete(at: t10)  // 10 seconds, 0 mistakes

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored != nil)
        #expect(stored?.timeSeconds == 10)
        #expect(stored?.mistakes == 0)
        #expect(stored?.rank == .perfect)  // 10s, 0 mistakes → Perfect per findAndFocus thresholds
    }

    // MARK: - Mistakes

    @Test func mistakeCountIncrementsCorrectly() async throws {
        let session = makeSession()
        try await session.start(at: t0)
        try await session.recordMistake()
        try await session.recordMistake()
        #expect(await session.mistakeCount == 2)
    }

    @Test func mistakeAffectsRankOnCompletion() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)
        try await session.recordMistake()  // 1 mistake
        try await session.complete(at: t10)  // 10s, 1 mistake → Good (not Perfect)

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored?.rank == .good)
    }

    // MARK: - Elapsed Time Across Pause/Resume

    /// Pause + resume preserves elapsed time correctly.
    @Test func elapsedTimeAccountsForPauseDuration() async throws {
        let storage = InMemoryStorageComponent()
        let session = makeSession(storage: storage)

        try await session.start(at: t0)    // start at 0
        try await session.pause(at: t10)   // pause at 10s → 10s elapsed
        try await session.resume(at: t20)  // resume at 20s (paused for 10s)
        try await session.complete(at: t30) // complete at 30s → 10s + (30-20) = 20s active

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored?.timeSeconds == 20)
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
}
