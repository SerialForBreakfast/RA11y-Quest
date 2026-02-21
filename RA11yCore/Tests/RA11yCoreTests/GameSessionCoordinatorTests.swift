import Testing
@testable import RA11yCore

// MARK: - GameSessionCoordinatorTests

/// Tests for `GameSessionCoordinator` — specifically the M2 requirement that
/// a VoiceOver-off event mid-session abandons the game without writing a result.
@MainActor
struct GameSessionCoordinatorTests {

    // MARK: - Helpers

    private func makeCoordinator(
        isVoiceOverRunning: Bool,
        stateChanges: AsyncStream<Bool> = AsyncStream { _ in }
    ) -> (GameSessionCoordinator, InMemoryStorageComponent) {
        let storage = InMemoryStorageComponent()
        let session = GameSession(
            gameID: "find-and-focus",
            thresholds: .findAndFocus,
            storage: storage
        )
        let stub = StubVoiceOverStateProvider(
            isVoiceOverRunning: isVoiceOverRunning,
            stateChanges: stateChanges
        )
        let coordinator = GameSessionCoordinator(
            session: session,
            gameKind: .findAndFocus,
            voiceOverProvider: stub
        )
        return (coordinator, storage)
    }

    // MARK: - VO-Off Mid-Game: Core Requirement

    @Test func voiceOverDisabledMidGameAbandonsSession() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, storage) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        coordinator.startMonitoring()

        continuation.yield(false)  // simulate VO being turned off
        try? await Task.sleep(nanoseconds: 20_000_000)  // 20 ms for scheduler

        #expect(await coordinator.session.state == .abandoned)
        continuation.finish()
    }

    @Test func voiceOverDisabledMidGameSetsObservableFlag() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, _) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        coordinator.startMonitoring()

        #expect(coordinator.voiceOverDisabledMidGame == false)

        continuation.yield(false)
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(coordinator.voiceOverDisabledMidGame == true)
        continuation.finish()
    }

    @Test func abandonedSessionWritesNoResultToStorage() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, storage) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        coordinator.startMonitoring()

        continuation.yield(false)
        try? await Task.sleep(nanoseconds: 20_000_000)

        let stored = await storage.bestResult(for: "find-and-focus")
        #expect(stored == nil)
        continuation.finish()
    }

    // MARK: - VO-On Events Are Ignored

    @Test func voiceOverOnEventsDontAffectRunningSession() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, _) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        coordinator.startMonitoring()

        continuation.yield(true)   // VO still on
        continuation.yield(true)
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(await coordinator.session.state == .running)
        #expect(coordinator.voiceOverDisabledMidGame == false)
        continuation.finish()
    }

    // MARK: - Already Terminal: No Double-Abandon

    @Test func voiceOverOffAfterNormalCompletionIsNoOp() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, storage) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        // Complete the session normally first
        try await coordinator.session.start()
        try await coordinator.session.complete()
        coordinator.startMonitoring()

        let resultBeforeVO = await storage.bestResult(for: "find-and-focus")

        continuation.yield(false)  // VO goes off, but session is already completed
        try? await Task.sleep(nanoseconds: 20_000_000)

        let resultAfterVO = await storage.bestResult(for: "find-and-focus")
        // Storage should be unchanged; completed result must not be wiped
        #expect(resultAfterVO == resultBeforeVO)
        #expect(coordinator.voiceOverDisabledMidGame == false)
        continuation.finish()
    }

    @Test func voiceOverOffAfterAbandonIsNoOp() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, _) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        await coordinator.session.abandon()
        coordinator.startMonitoring()

        continuation.yield(false)
        try? await Task.sleep(nanoseconds: 20_000_000)

        // Still abandoned, flag unchanged (wasn't set by coordinator because session was already abandoned)
        #expect(await coordinator.session.state == .abandoned)
        #expect(coordinator.voiceOverDisabledMidGame == false)
        continuation.finish()
    }

    // MARK: - Paused Session: Also Abandoned on VO-Off

    @Test func voiceOverDisabledWhilePausedAbandonsSession() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, storage) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        try await coordinator.session.pause()
        coordinator.startMonitoring()

        continuation.yield(false)
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(await coordinator.session.state == .abandoned)
        #expect(coordinator.voiceOverDisabledMidGame == true)
        #expect(await storage.bestResult(for: "find-and-focus") == nil)
        continuation.finish()
    }

    // MARK: - GameKind Preservation

    @Test func coordinatorPreservesGameKind() {
        let (coordinator, _) = makeCoordinator(isVoiceOverRunning: true)
        #expect(coordinator.gameKind == .findAndFocus)
    }

    // MARK: - Stop Monitoring

    @Test func stopMonitoringPreventsAbandonOnVOOff() async throws {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let (coordinator, _) = makeCoordinator(isVoiceOverRunning: true, stateChanges: stream)

        try await coordinator.session.start()
        coordinator.startMonitoring()
        coordinator.stopMonitoring()

        continuation.yield(false)
        try? await Task.sleep(nanoseconds: 20_000_000)

        // Monitoring was cancelled before the event; session stays running
        #expect(await coordinator.session.state == .running)
        #expect(coordinator.voiceOverDisabledMidGame == false)
        continuation.finish()
    }
}
