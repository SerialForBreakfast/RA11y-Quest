import SwiftUI
import UIKit
import RA11yCore

// MARK: - GameKind + ambient art

extension GameKind {

    /// Full-bleed painting behind ``iOSGameResultView`` (post-run, dramatic).
    var questResultAmbientImageName: String {
        switch self {
        case .findAndFocus: return "enchanter_tower_shelf_bg"
        case .scrollHunt: return "dungeon_descent_bg"
        case .banishment: return iOSBanishmentArt.towerBackground
        }
    }

    /// Full-bleed painting behind ``iOSVORequiredView`` (matches the quest the player was entering).
    ///
    /// Banishment uses the ward master so the gate matches the practice tone before the tower gauntlet.
    var questVoiceOverGateAmbientImageName: String {
        switch self {
        case .findAndFocus: return "enchanter_tower_shelf_bg"
        case .scrollHunt: return "dungeon_descent_bg"
        case .banishment: return iOSBanishmentArt.wardBackground
        }
    }
}

// MARK: - Backdrop views

/// Illustrated quest environment (Enchanter shelf, Dungeon shaft, Banishment art).
struct QuestPaintAmbientBackdrop: View {

    let imageName: String

    var body: some View {
        Group {
            if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.ra11yGameFallbackBackground
            }
        }
    }
}

/// Dark gradient scrim so mockup-style serif/body copy stays legible over busy paintings.
struct QuestPaintReadableScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.32), location: 0),
                .init(color: .black.opacity(0.56), location: 0.42),
                .init(color: .black.opacity(0.78), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Reading lane metrics

/// Horizontal metrics for scroll content over full-bleed quest art (phone, iPad, Dungeon result gutters).
enum QuestPaintContentMetrics {

    /// Outside padding for a scroll column; widens on compact widths and adds ribbon inset for Dungeon results.
    static func scrollHorizontalPadding(
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        gameKind: GameKind?
    ) -> CGFloat {
        let readingCap: CGFloat = horizontalSizeClass == .regular ? 640 : 560
        let centered = max(0, (containerWidth - readingCap) / 2)
        var pad = max(RA11ySpacing.base, centered)
        if horizontalSizeClass == .regular {
            pad = max(pad, RA11ySpacing.xl)
        }
        if gameKind == .scrollHunt {
            pad += RA11ySpacing.md
        }
        return pad
    }

    /// Maximum width of the reading column inside horizontal padding (keeps line length comfortable on iPad).
    static func readingColumnMaxWidth(
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        let cap: CGFloat = horizontalSizeClass == .regular ? 620 : 560
        return min(max(containerWidth - horizontalPadding * 2, 0), cap)
    }
}

// MARK: - Mockup-aligned typography (Dynamic Type)

/// Fantasy mockup roles: serif hero lines, warm neutrals, gold captions — all scale with Dynamic Type.
enum QuestPaintReadableTextRole {
    /// Large serif title over paint (prologue, VO gate).
    case heroTitle
    /// Section / card headline (serif).
    case sectionTitle
    /// Primary reading line on scrim or dark paint.
    case bodyEmphasis
    /// Supporting copy on scrim or dark paint.
    case bodySupporting
    /// Uppercase kicker (warm gold).
    case captionGold
    /// Headline on ``Material`` cards (results skill transfer, trap sheet).
    case materialCardTitle
    /// Body on ``Material`` cards.
    case materialCardBody
    /// Fine print on ``Material`` cards.
    case materialCardMeta
}

struct QuestPaintReadableTextModifier: ViewModifier {
    let role: QuestPaintReadableTextRole

    func body(content: Content) -> some View {
        switch role {
        case .heroTitle:
            content
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 2)
        case .sectionTitle:
            content
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
        case .bodyEmphasis:
            content
                .font(Font.ra11yBody.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.94))
                .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
        case .bodySupporting:
            content
                .font(Font.ra11yBody)
                .foregroundStyle(Color.white.opacity(0.84))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        case .captionGold:
            content
                .font(Font.ra11yCaption.weight(.semibold))
                .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
        case .materialCardTitle:
            content
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.96))
        case .materialCardBody:
            content
                .font(Font.ra11yBody)
                .foregroundStyle(Color.white.opacity(0.86))
        case .materialCardMeta:
            content
                .font(Font.ra11ySubheadline)
                .foregroundStyle(Color.white.opacity(0.72))
        }
    }
}

extension View {

    /// Applies mockup-derived legibility styling for text over illustrated environments or material cards.
    func questPaintReadableText(_ role: QuestPaintReadableTextRole) -> some View {
        modifier(QuestPaintReadableTextModifier(role: role))
    }
}
