import Testing
@testable import RA11yCore

// MARK: - HubViewModelTests

/// Tests for `HubViewModel.showHelpAffordance` driven by VoiceOver state.
///
/// Validates TICKET-M2-HelpAffordance-Visibility acceptance criteria:
/// - VO ON  → `showHelpAffordance == false` (affordance removed from hierarchy)
/// - VO OFF → `showHelpAffordance == true`  (affordance visible)
///
/// All tests use `StubVoiceOverStateProvider` — no UIKit or system state.
/// `@MainActor` required because `HubViewModel` is `@MainActor`.
@MainActor
struct HubViewModelTests {

    // MARK: - Initial State

    /// Primary acceptance criterion: VO ON → help affordance is hidden.
    @Test func voiceOverOnSetsShowHelpAffordanceToFalse() {
        let stub      = StubVoiceOverStateProvider(isVoiceOverRunning: true)
        let viewModel = HubViewModel(voiceOverProvider: stub)
        #expect(viewModel.showHelpAffordance == false)
    }

    @Test func voiceOverOffSetsShowHelpAffordanceToTrue() {
        let stub      = StubVoiceOverStateProvider(isVoiceOverRunning: false)
        let viewModel = HubViewModel(voiceOverProvider: stub)
        #expect(viewModel.showHelpAffordance == true)
    }

    // MARK: - Reactive Updates

    /// When VO is toggled off while the hub is visible, the affordance appears.
    @Test func stateChangeFromOnToOffShowsAffordance() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let stub      = StubVoiceOverStateProvider(isVoiceOverRunning: true, stateChanges: stream)
        let viewModel = HubViewModel(voiceOverProvider: stub)

        #expect(viewModel.showHelpAffordance == false)

        continuation.yield(false)
        // Allow the HubViewModel's internal @MainActor Task to wake, receive the
        // event, and update the property before we read it.
        try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms

        #expect(viewModel.showHelpAffordance == true)
        continuation.finish()
    }

    /// When VO is toggled on while the hub is visible, the affordance disappears.
    @Test func stateChangeFromOffToOnHidesAffordance() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let stub      = StubVoiceOverStateProvider(isVoiceOverRunning: false, stateChanges: stream)
        let viewModel = HubViewModel(voiceOverProvider: stub)

        #expect(viewModel.showHelpAffordance == true)

        continuation.yield(true)
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(viewModel.showHelpAffordance == false)
        continuation.finish()
    }

    /// Multiple rapid VO toggles converge to the final state.
    @Test func rapidTogglesConvergeToFinalState() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let stub      = StubVoiceOverStateProvider(isVoiceOverRunning: true, stateChanges: stream)
        let viewModel = HubViewModel(voiceOverProvider: stub)

        continuation.yield(false)
        continuation.yield(true)
        continuation.yield(false)   // final state: VO off → affordance shown
        continuation.finish()

        // Allow all three events to be processed.
        try? await Task.sleep(nanoseconds: 20_000_000) // 20 ms

        #expect(viewModel.showHelpAffordance == true)
    }
}
