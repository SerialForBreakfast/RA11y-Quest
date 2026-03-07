import SwiftUI
import RA11yCore

// MARK: - iOSQuestCardInfoView

/// Middle text block of a quest card: game title, one-line goal, and estimated duration.
///
/// Uses `.layoutPriority(1)` when embedded in the parent `HStack` so this block
/// receives available space before the fixed-size thumbnail and badge compete for it.
/// Text wraps naturally — card height grows to accommodate; no truncation.
///
/// Marked `.accessibilityHidden(true)` because the parent `iOSQuestCardView` Button
/// provides the full combined accessibility label covering title, goal, duration,
/// and rank. This view is purely visual.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSQuestCardInfoView: View {

    // MARK: - Properties

    /// Localized display title (e.g., "The Enchanter's Trial").
    let title: String

    /// Localized one-line goal description.
    let goal: String

    /// Human-readable estimated duration (e.g., "~5 min").
    let estimatedDuration: String

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Text(title)
                .font(.ra11yHeadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(goal)
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(estimatedDuration)
                .font(.ra11yCaption)
                .foregroundStyle(Color.ra11yCardTertiaryText)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    iOSQuestCardInfoView(
        title: "The Enchanter's Trial",
        goal: "Navigate focus and invoke the named relic.",
        estimatedDuration: "~5 min"
    )
    .padding()
    .background(Color(white: 0.15))
}
