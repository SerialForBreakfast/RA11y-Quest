/// Pure reducer that converts semantic gameplay inputs into reusable feedback intents.
///
/// The reducer is intentionally platform-agnostic. It should be fed with semantic state
/// changes, not raw scroll deltas, so platform renderers can stay small and reusable.
public enum QuestFeedbackReducer {

    /// Applies one semantic input to the reducer state and returns any feedback intents
    /// that should be rendered for the transition.
    ///
    /// - Parameters:
    ///   - state: Mutable reducer state.
    ///   - input: Semantic gameplay input.
    /// - Returns: Zero or more feedback intents for the transition.
    public static func reduce(
        state: inout QuestFeedbackState,
        input: QuestFeedbackInput
    ) -> [QuestFeedbackIntent] {
        switch input {
        case .alignmentBandChanged(let newBand):
            return reduceBandChange(state: &state, newBand: newBand)
        case .laneSlotChanged:
            return [.laneSlotTick]
        case .wrongActivation:
            return [.wrongActivation]
        case .success:
            return [.success]
        case .timeout:
            return [.timeout]
        case .hintRequested:
            return [.hint]
        }
    }

    private static func reduceBandChange(
        state: inout QuestFeedbackState,
        newBand: QuestFeedbackBand
    ) -> [QuestFeedbackIntent] {
        let previous = state.currentBand
        state.currentBand = newBand

        guard previous != newBand else { return [] }

        switch (previous, newBand) {
        case (_, .far):
            if previous == .locked {
                return [.lockLost]
            }
            return []

        case (_, .warm):
            if previous == .locked {
                return [.lockLost, .proximityEntered(.warm)]
            }
            return [.proximityEntered(.warm)]

        case (_, .near):
            if previous == .locked {
                return [.lockLost, .proximityEntered(.near)]
            }
            return [.proximityEntered(.near)]

        case (_, .locked):
            return [.lockAcquired]
        }
    }
}
