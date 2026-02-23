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
/// Format: "{title}. {goal}. {estimatedDuration}. Rank: {rankLabel}."
/// Hint: "Double-tap to begin this trial."
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
    let onTap: () -> Void

    // MARK: - Environment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Computed

    private var isLargeAccessibilitySize: Bool {
        dynamicTypeSize >= .accessibility2
    }

    private var cardPadding: CGFloat {
        sizeClass == .regular ? RA11ySpacing.lg : RA11ySpacing.base
    }

    private var cardSpacing: CGFloat { 16 }

    private var rankLabel: String {
        if let rank {
            return rank.displayText
        }
        return String(localized: "hub.questAwaits")
    }

    private var combinedAccessibilityLabel: String {
        let title    = String(localized: String.LocalizationValue(game.titleKey))
        let goal     = String(localized: String.LocalizationValue(game.goalKey))
        let duration = game.estimatedDuration
        return "\(title). \(goal). \(duration). Rank: \(rankLabel)."
    }

    private var thumbnailSaturation: Double {
        rank == nil ? 0.4 : 1.0
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(QuestCardButtonStyle())
        .accessibilityLabel(combinedAccessibilityLabel)
        .accessibilityHint(String(localized: "hub.card.accessibilityHint"))
        .accessibilityAddTraits(.isButton)
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

            iOSQuestCardInfoView(
                title: String(localized: String.LocalizationValue(game.titleKey)),
                goal: String(localized: String.LocalizationValue(game.goalKey)),
                estimatedDuration: game.estimatedDuration
            )
            .layoutPriority(1)

            iOSRankBadgeView(rank: rank, isAccessibilityHidden: true)
        }
        // Explicit maxWidth makes the card background stretch to the full available
        // width rather than hugging its content in context-dependent sizing.
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
    }

    /// VStack layout for `.accessibility2` and above — prevents horizontal crowding.
    private var largeTypeLayout: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            HStack {
                iOSQuestThumbnailView(assetName: game.thumbnailAssetName)
                    .saturation(thumbnailSaturation)
                Spacer()
                iOSRankBadgeView(rank: rank, isAccessibilityHidden: true)
            }
            iOSQuestCardInfoView(
                title: String(localized: String.LocalizationValue(game.titleKey)),
                goal: String(localized: String.LocalizationValue(game.goalKey)),
                estimatedDuration: game.estimatedDuration
            )
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
    }
}

// MARK: - QuestCardButtonStyle

/// Custom button style that renders the quest card's visual chrome.
///
/// Handling press state via `configuration.isPressed` here rather than in the
/// card body keeps the visual treatment decoupled from the content layout.
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
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.ra11yCardSurfaceHighlight,
                                Color.ra11yCardSurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RA11yRadius.card)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.ra11yCardBorder.opacity(0.9),
                                        Color.ra11yGoldDeep.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.6
                            )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
            )
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
        onTap: {}
    )
    .padding()
    .background(Color(white: 0.08))
}

#Preview("Quest Awaits — standard type") {
    iOSQuestCardView(
        game: GameCatalog.all[1],
        rank: nil,
        onTap: {}
    )
    .padding()
    .background(Color(white: 0.08))
}
