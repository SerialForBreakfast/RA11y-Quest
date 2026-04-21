import Testing
@testable import RA11yCore

// MARK: - QuestFeedbackReducerTests

/// Tests for reusable semantic feedback reduction used by multiple quests.
struct QuestFeedbackReducerTests {

    @Test func enteringWarmBandEmitsWarmProximityIntent() {
        var state = QuestFeedbackState()

        let intents = QuestFeedbackReducer.reduce(
            state: &state,
            input: .alignmentBandChanged(.warm)
        )

        #expect(intents == [.proximityEntered(.warm)])
        #expect(state.currentBand == .warm)
    }

    @Test func movingFromWarmToNearEmitsNearProximityIntent() {
        var state = QuestFeedbackState(currentBand: .warm)

        let intents = QuestFeedbackReducer.reduce(
            state: &state,
            input: .alignmentBandChanged(.near)
        )

        #expect(intents == [.proximityEntered(.near)])
        #expect(state.currentBand == .near)
    }

    @Test func enteringLockedBandEmitsLockAcquired() {
        var state = QuestFeedbackState(currentBand: .near)

        let intents = QuestFeedbackReducer.reduce(
            state: &state,
            input: .alignmentBandChanged(.locked)
        )

        #expect(intents == [.lockAcquired])
        #expect(state.currentBand == .locked)
    }

    @Test func leavingLockedForNearEmitsLockLostThenNear() {
        var state = QuestFeedbackState(currentBand: .locked)

        let intents = QuestFeedbackReducer.reduce(
            state: &state,
            input: .alignmentBandChanged(.near)
        )

        #expect(intents == [.lockLost, .proximityEntered(.near)])
        #expect(state.currentBand == .near)
    }

    @Test func repeatingSameBandEmitsNothing() {
        var state = QuestFeedbackState(currentBand: .near)

        let intents = QuestFeedbackReducer.reduce(
            state: &state,
            input: .alignmentBandChanged(.near)
        )

        #expect(intents.isEmpty)
    }

    @Test func wrongActivationEmitsWrongActivationIntent() {
        var state = QuestFeedbackState(currentBand: .near)

        let intents = QuestFeedbackReducer.reduce(state: &state, input: .wrongActivation)

        #expect(intents == [.wrongActivation])
        #expect(state.currentBand == .near)
    }

    @Test func successEmitsSuccessIntent() {
        var state = QuestFeedbackState(currentBand: .locked)

        let intents = QuestFeedbackReducer.reduce(state: &state, input: .success)

        #expect(intents == [.success])
    }

    @Test func timeoutEmitsTimeoutIntent() {
        var state = QuestFeedbackState(currentBand: .warm)

        let intents = QuestFeedbackReducer.reduce(state: &state, input: .timeout)

        #expect(intents == [.timeout])
    }

    @Test func hintRequestEmitsHintIntent() {
        var state = QuestFeedbackState(currentBand: .far)

        let intents = QuestFeedbackReducer.reduce(state: &state, input: .hintRequested)

        #expect(intents == [.hint])
    }

    @Test func laneSlotChangeEmitsLaneSlotTickWithoutMutatingBandState() {
        var state = QuestFeedbackState(currentBand: .near)

        let intents = QuestFeedbackReducer.reduce(state: &state, input: .laneSlotChanged)

        #expect(intents == [.laneSlotTick])
        #expect(state.currentBand == .near)
    }

    @Test func dungeonResonanceProfileUsesAlignmentSnapForLockCue() {
        let profile = QuestFeedbackProfile.dungeonResonance
        #expect(profile.lockCue.haptic == .alignmentSnap)
        #expect(profile.lockCue.audio == .resonance)
    }
}
