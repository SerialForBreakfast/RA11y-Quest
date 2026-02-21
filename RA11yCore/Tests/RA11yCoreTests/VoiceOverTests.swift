import Testing
@testable import RA11yCore

// MARK: - VoiceOverTests

/// Tests for `GameStartDecision` routing logic.
///
/// Validates TICKET-M2-VoiceOverStateProvider acceptance criteria:
/// - VO OFF → `.requireVoiceOver` (interstitial route)
/// - VO ON  → `.proceed` (game route)
///
/// All tests use `StubVoiceOverStateProvider` — no UIKit or system state dependency.
struct VoiceOverTests {

    // MARK: - GameStartDecision

    /// Primary acceptance criterion: VO off → interstitial decision.
    @Test func voiceOverOffProducesRequireVoiceOverDecision() {
        let stub     = StubVoiceOverStateProvider(isVoiceOverRunning: false)
        let decision = GameStartDecision.evaluate(kind: .findAndFocus, provider: stub)
        #expect(decision == .requireVoiceOver(kind: .findAndFocus))
    }

    @Test func voiceOverOnProducesProceedDecision() {
        let stub     = StubVoiceOverStateProvider(isVoiceOverRunning: true)
        let decision = GameStartDecision.evaluate(kind: .findAndFocus, provider: stub)
        #expect(decision == .proceed(kind: .findAndFocus))
    }

    /// Decision carries the correct `GameKind` regardless of VO state.
    @Test func decisionPreservesGameKind() {
        for kind in GameKind.allCases {
            let offDecision = GameStartDecision.evaluate(
                kind: kind,
                provider: StubVoiceOverStateProvider(isVoiceOverRunning: false)
            )
            let onDecision = GameStartDecision.evaluate(
                kind: kind,
                provider: StubVoiceOverStateProvider(isVoiceOverRunning: true)
            )
            #expect(offDecision == .requireVoiceOver(kind: kind))
            #expect(onDecision  == .proceed(kind: kind))
        }
    }

    // MARK: - StubVoiceOverStateProvider

    @Test func stubReportsCorrectInitialState() {
        #expect(StubVoiceOverStateProvider(isVoiceOverRunning: true).isVoiceOverRunning == true)
        #expect(StubVoiceOverStateProvider(isVoiceOverRunning: false).isVoiceOverRunning == false)
    }

    /// Stub's default stateChanges stream does not yield — safe for routing tests.
    @Test func stubDefaultStreamNeverYields() async {
        let stub = StubVoiceOverStateProvider(isVoiceOverRunning: false)

        // Race the stream against a short timeout. If the stream yields first,
        // firstEmitted will be non-nil; if the timeout wins, it stays nil.
        let firstEmitted: Bool? = await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                for await value in stub.stateChanges { return value }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(10))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }

        #expect(firstEmitted == nil)
    }
}
