import Testing
@testable import RA11yCore

// MARK: - VoiceOverTests

/// Tests for `GameStartDecision` routing logic and `StubVoiceOverStateProvider` behavior.
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

    /// Decision carries the correct `GameKind` for every case.
    ///
    /// Ensures the kind is not hardcoded or lost during evaluation.
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

    /// The stub's default `stateChanges` stream must not yield within the test window.
    ///
    /// If the default stream yielded immediately, routing tests that subscribe to it
    /// would see spurious state changes and produce false results.
    @Test func stubDefaultStreamNeverYields() async {
        let stub = StubVoiceOverStateProvider(isVoiceOverRunning: false)

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
