import Foundation

// MARK: - GameResultPresenter

/// Pure formatting layer for displaying a `GameResult` in UI and VoiceOver.
///
/// Contains no SwiftUI or UIKit dependencies, making it testable in isolation
/// from any UI framework. The iOS result view consumes this to populate labels
/// and compose the accessibility announcement.
///
/// ## VoiceOver Announcement Order
/// Per `TICKET-M1-SharedGameResultScreen`: rank → time → mistakes.
/// Example: `"Perfect. 8.5 seconds. 0 mistakes."`
public struct GameResultPresenter: Sendable {

    /// The underlying result being presented.
    public let result: GameResult

    /// - Parameter result: The completed session result to present.
    public init(result: GameResult) {
        self.result = result
    }

    // MARK: - Formatted Display

    /// Time formatted for display (e.g., `"8.5 seconds"` or `"12.0 seconds"`).
    public var formattedTime: String {
        String(format: "%.1f seconds", result.timeSeconds)
    }

    /// Mistakes formatted with correct singular/plural (e.g., `"1 mistake"`, `"0 mistakes"`).
    public var formattedMistakes: String {
        result.mistakes == 1 ? "1 mistake" : "\(result.mistakes) mistakes"
    }

    // MARK: - Accessibility

    /// Full VoiceOver announcement string for the result screen.
    ///
    /// Announce order: rank → time → mistakes (as specified in `TICKET-M1-SharedGameResultScreen`).
    ///
    /// Assign to `.accessibilityLabel` on the result summary container so VoiceOver
    /// reads it as a single logical unit.
    public var accessibilityAnnouncement: String {
        "\(result.rank.displayText). \(formattedTime). \(formattedMistakes)."
    }
}
