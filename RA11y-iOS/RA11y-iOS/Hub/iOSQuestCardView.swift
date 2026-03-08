import SwiftUI
import RA11yCore

// MARK: - iOSQuestCardView

/// A tappable quest card representing one training game on the hub screen.
///
/// The entire card is a single `Button` — one VoiceOver focus element. Sub-views
/// (`iOSQuestThumbnailView`, `iOSQuestCardInfoView`, `iOSRankBadgeView`) are all
/// marked `.accessibilityHidden(true)` and are covered by the button's combined label.
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
/// ## Adaptive Layout
/// - Standard (`dynamicTypeSize < .accessibility2`): `HStack` — thumbnail | info | badge
/// - Large accessibility sizes: `VStack` — thumbnail + badge row on top, info below
///
/// ## Visual Design
/// Dark warm card surface with an amber/gold border. Slight elevation shadow.
/// Unplayed cards use a slightly desaturated thumbnail (via `.saturation`).
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
                    estimatedDuration: game.estimatedDuration
                )
                .layoutPriority(1)
                iOSRankBadgeView(rank: rank, isAccessibilityHidden: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .opacity(isLocked ? 0.55 : 1.0)
    }

    /// VStack layout for `.accessibility2` and above — prevents horizontal crowding.
    private var largeTypeLayout: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            HStack {
                iOSQuestThumbnailView(assetName: game.thumbnailAssetName)
                    .saturation(thumbnailSaturation)
                Spacer()
                if !isLocked {
                    iOSRankBadgeView(rank: rank, isAccessibilityHidden: true)
                }
            }
            if isLocked {
                lockedInfoColumn
            } else {
                iOSQuestCardInfoView(
                    title: String(localized: String.LocalizationValue(game.titleKey)),
                    goal: String(localized: String.LocalizationValue(game.goalKey)),
                    estimatedDuration: game.estimatedDuration
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
/// Handling press state via `configuration.isPressed` here rather than in the
/// card body keeps the visual treatment decoupled from the content layout.
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
/// perceptible without motion. This satisfies the M3 and M8 Reduce Motion
/// acceptance criteria.
private struct QuestCardButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.13, green: 0.10, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                Color(red: 0.75, green: 0.55, blue: 0.10).opacity(0.6),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            )
            // Force dark environment so all semantic colors (`.primary`, `.secondary`,
            // etc.) resolve to white-based values on the fixed-dark card surface.
            // This is the correct idiom for a non-adaptive dark surface in SwiftUI —
            // it handles light mode, dark mode, and Increase Contrast in one place.
            .environment(\.colorScheme, .dark)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            // Scale feedback is motion-based; suppress it when Reduce Motion is ON.
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
