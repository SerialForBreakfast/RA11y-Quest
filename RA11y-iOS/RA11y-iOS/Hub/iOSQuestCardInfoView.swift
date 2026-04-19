import SwiftUI
import RA11yCore

// MARK: - iOSQuestCardInfoView

/// Middle text block of a quest card: game title, one-line goal, estimated duration,
/// and an inline rank chip.
///
/// Uses `.layoutPriority(1)` when embedded in the parent `HStack` so this block
/// receives available space before the fixed-size thumbnail competes for it.
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

    /// Rank display label ("Quest Awaits" or rank name). Shown as a compact inline chip.
    let rankLabel: String

    /// Color for the rank chip dot and text.
    let rankColor: Color

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

            HStack(alignment: .center, spacing: RA11ySpacing.sm) {
                Text(estimatedDuration)
                    .font(.ra11yCaption)
                    .foregroundStyle(Color.ra11yCardTertiaryText)

                rankChip
            }
            .padding(.top, 2)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Rank Chip

    /// Compact inline status indicator: a small colored dot + rank label text.
    ///
    /// Replaces the large `iOSRankBadgeView` column so the title and goal text have
    /// the full card width without wrapping.
    private var rankChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(rankColor)
                .frame(width: 6, height: 6)

            Text(rankLabel)
                .font(.ra11yCaption)
                .fontWeight(.semibold)
                .foregroundStyle(rankColor)
        }
    }
}

// MARK: - Preview

#Preview("Unplayed") {
    iOSQuestCardInfoView(
        title: "The Enchanter's Trial",
        goal: "Navigate focus and invoke the named relic.",
        estimatedDuration: "~5 min",
        rankLabel: "Quest Awaits",
        rankColor: Color(white: 0.55)
    )
    .padding()
    .background(Color(white: 0.15))
}

#Preview("Legendary") {
    iOSQuestCardInfoView(
        title: "The Enchanter's Trial",
        goal: "Navigate focus and invoke the named relic.",
        estimatedDuration: "~5 min",
        rankLabel: "Legendary",
        rankColor: Color(red: 1.0, green: 0.84, blue: 0.0)
    )
    .padding()
    .background(Color(white: 0.15))
}
