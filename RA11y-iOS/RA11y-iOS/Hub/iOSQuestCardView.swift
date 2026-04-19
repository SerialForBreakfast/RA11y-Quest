import SwiftUI
import RA11yCore

// MARK: - iOSQuestCardView

/// A tappable quest card representing one training game on the hub screen.
///
/// The entire card is a single `Button` — one VoiceOver focus element. Sub-views
/// (`iOSQuestThumbnailView`, `iOSQuestCardInfoView`) are all marked
/// `.accessibilityHidden(true)` and are covered by the button's combined label.
///
/// ## Combined VoiceOver Label
/// - Unlocked: "{title}. {goal}. {estimatedDuration}. Rank: {rankLabel}."
/// - Locked: "{title}. {lockedMessage}."
///
/// ## Locked State
/// When `prerequisiteTitle` is non-nil the card is rendered in a dimmed, non-interactive
/// locked state with a lock icon overlay. The button is disabled so VoiceOver does not
/// offer an activation hint. A "Complete [prerequisiteTitle] to unlock" message replaces
/// the goal/duration/rank row in the combined label.
///
/// ## Layout
/// Thumbnail on the left; info column (title, goal, duration + compact rank chip) fills
/// the remaining width. The large `iOSRankBadgeView` column has been removed from the
/// HStack — its information lives in the inline rank chip inside `iOSQuestCardInfoView`.
///
/// ## Adaptive Layout
/// - Standard (`dynamicTypeSize < .accessibility2`): `HStack` — thumbnail | info
/// - Large accessibility sizes: `VStack` — thumbnail on top, info below
///
/// ## Visual Design
/// Dark warm card surface (15% transparent so the dungeon background shows through)
/// with an amber/gold border. Slight elevation shadow.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSQuestCardView: View {

    // MARK: - Properties

    let game: GameDefinition
    let rank: GameRank?
    /// Display title of the prerequisite game, or `nil` when unlocked.
    let prerequisiteTitle: String?
    let onTap: () -> Void

    // MARK: - Environment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Computed

    private var isLocked: Bool { prerequisiteTitle != nil }

    private var isLargeAccessibilitySize: Bool {
        dynamicTypeSize >= .accessibility2
    }

    private var cardPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.lg : RA11ySpacing.md
    }

    private var cardSpacing: CGFloat { 12 }

    private var rankLabel: String {
        if let rank {
            return rank.displayText
        }
        return String(localized: "hub.questAwaits")
    }

    /// Thematic color for the inline rank chip. Mirrors the seal colors in `iOSRankBadgeView`.
    private var rankChipColor: Color {
        guard let rank else { return Color.ra11yCardTertiaryText }
        switch rank {
        case .perfect: return Color(red: 1.0,  green: 0.84, blue: 0.0)
        case .good:    return Color(red: 0.53, green: 0.81, blue: 0.98)
        case .ok:      return Color(red: 0.75, green: 0.65, blue: 0.50)
        case .failed:  return Color(red: 0.55, green: 0.55, blue: 0.55)
        }
    }

    private var combinedAccessibilityLabel: String {
        let title = String(localized: String.LocalizationValue(game.titleKey))
        if let prerequisiteTitle {
            let lockMsg = String(
                format: String(localized: "hub.card.locked.a11yLabel"),
                prerequisiteTitle
            )
            return "\(title). \(lockMsg)."
        }
        let goal     = String(localized: String.LocalizationValue(game.goalKey))
        let duration = game.estimatedDuration
        return "\(title). \(goal). \(duration). Rank: \(rankLabel)."
    }

    private var thumbnailSaturation: Double {
        isLocked ? 0.0 : (rank == nil ? 0.4 : 1.0)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                cardContent
                if isLocked {
                    lockOverlay
                }
            }
        }
        .buttonStyle(QuestCardButtonStyle())
        .disabled(isLocked)
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityHint(isLocked ? "" : String(localized: "hub.card.accessibilityHint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("questCard.\(game.id)")
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        if isLargeAccessibilitySize {
            largeTypeLayout
        } else {
            standardLayout
        }
    }

    /// Standard HStack layout for default through `.accessibility1` type sizes.
    ///
    /// Thumbnail on the left; info column (with inline rank chip) fills remaining space.
    /// The separate rank badge column has been removed — the chip in the info view
    /// gives the title and goal text the full available width.
    private var standardLayout: some View {
        HStack(alignment: .top, spacing: cardSpacing) {
            iOSQuestThumbnailView(assetName: game.thumbnailAssetName)
                .saturation(thumbnailSaturation)

            if isLocked {
                lockedInfoColumn
            } else {
                iOSQuestCardInfoView(
                    title: String(localized: String.LocalizationValue(game.titleKey)),
                    goal: String(localized: String.LocalizationValue(game.goalKey)),
                    estimatedDuration: game.estimatedDuration,
                    rankLabel: rankLabel,
                    rankColor: rankChipColor
                )
                .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .opacity(isLocked ? 0.55 : 1.0)
    }

    /// VStack layout for `.accessibility2` and above — prevents horizontal crowding.
    private var largeTypeLayout: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            iOSQuestThumbnailView(assetName: game.thumbnailAssetName)
                .saturation(thumbnailSaturation)

            if isLocked {
                lockedInfoColumn
            } else {
                iOSQuestCardInfoView(
                    title: String(localized: String.LocalizationValue(game.titleKey)),
                    goal: String(localized: String.LocalizationValue(game.goalKey)),
                    estimatedDuration: game.estimatedDuration,
                    rankLabel: rankLabel,
                    rankColor: rankChipColor
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .opacity(isLocked ? 0.55 : 1.0)
    }

    /// Info column shown when the game is locked — title + unlock message.
    private var lockedInfoColumn: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.xs) {
            Text(String(localized: String.LocalizationValue(game.titleKey)))
                .font(.ra11yHeadline)
                .foregroundStyle(Color.ra11yCardSecondaryText)
            if let prerequisiteTitle {
                Text(
                    String(
                        format: String(localized: "hub.card.locked.message"),
                        prerequisiteTitle
                    )
                )
                .font(.ra11ySubheadline)
                .foregroundStyle(Color.ra11yCardTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .layoutPriority(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Lock icon shown in the top-trailing corner for locked cards.
    private var lockOverlay: some View {
        Image(systemName: "lock.fill")
            .font(.ra11ySubheadline)
            .foregroundStyle(Color.ra11yAccent)
            .padding(RA11ySpacing.sm)
            .accessibilityHidden(true)
    }
}

// MARK: - QuestCardButtonStyle

/// Custom button style that renders the quest card's visual chrome.
///
/// The card fill uses 85% opacity (15% transparent) so the dungeon background
/// shows through subtly, grounding the cards in the scene.
///
/// ## Color Scheme Forcing
/// The card surface uses a fixed dark background regardless of the system's
/// light/dark mode setting. `.environment(\.colorScheme, .dark)` is applied to
/// the entire card so ALL semantic adaptive colors — `.primary`, `.secondary`,
/// and any future additions — resolve to their dark-mode values (white, dimmed
/// white, etc.) without requiring explicit color overrides on every `Text` view.
///
/// This also respects "Increase Contrast": in dark mode + high contrast, system
/// primary = bright white, giving an even higher contrast ratio on the dark surface.
///
/// ## Reduce Motion
/// When `accessibilityReduceMotion` is `true`, scale and opacity transitions are
/// suppressed. Only the `.opacity` feedback remains so the press is still
/// perceptible without motion.
private struct QuestCardButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.13, green: 0.10, blue: 0.09, opacity: 0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                Color(red: 0.75, green: 0.55, blue: 0.10).opacity(0.6),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            )
            .environment(\.colorScheme, .dark)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.98 : 1.0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Previews

#Preview("Legendary — standard type") {
    iOSQuestCardView(
        game: GameCatalog.all[0],
        rank: .perfect,
        prerequisiteTitle: nil,
        onTap: {}
    )
    .padding()
    .background(Color(white: 0.08))
}

#Preview("Quest Awaits — standard type") {
    iOSQuestCardView(
        game: GameCatalog.all[1],
        rank: nil,
        prerequisiteTitle: nil,
        onTap: {}
    )
    .padding()
    .background(Color(white: 0.08))
}

#Preview("Locked — prerequisite not completed") {
    iOSQuestCardView(
        game: GameCatalog.all[1],
        rank: nil,
        prerequisiteTitle: "The Enchanter's Trial",
        onTap: {}
    )
    .padding()
    .background(Color(white: 0.08))
}
