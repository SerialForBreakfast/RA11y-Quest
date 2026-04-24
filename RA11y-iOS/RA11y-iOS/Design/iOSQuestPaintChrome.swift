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
                    /// Prevents aspect-fill images from expanding the layout proposal when used as a full-bleed backdrop.
                    .clipped()
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

// MARK: - Layout roles & metrics

/// Adaptive width **role** for quest UI — replaces a single “reading column” for every surface.
///
/// ## Width targets (design system)
///
/// Use ``QuestPaintContentMetrics/horizontalPadding(role:containerWidth:horizontalSizeClass:gameKind:)`` and
/// ``QuestPaintContentMetrics/contentMaxWidth(role:containerWidth:horizontalSizeClass:horizontalPadding:)``.
///
/// | Role | Compact (typical phone) | Regular (typical iPad) |
/// |------|-------------------------|-------------------------|
/// | ``reading`` | Max content **560pt**, padding from centered 560 anchor | Max content **620pt**, padding from 640 anchor |
/// | ``questCardList`` | Max **560pt** (full width minus padding) | Max **800pt**, wider anchor **840pt** so titles don’t phone-wrap |
/// | ``lesson`` | Same as reading (until prologue unification) | Same as reading |
/// | ``playfield`` | Same as reading | Same as reading |
/// | ``actions`` | Same as reading | Same as reading |
///
/// - Note: Changing layout roles can affect VoiceOver reading order and Dynamic Type clipping — re-validate affected screens.
enum QuestLayoutRole: Equatable, Sendable {
    /// Comfortable line length for narrative copy, result prose, and the VoiceOver gate — **560pt** max on phone, **620pt** on iPad regular.
    case reading
    /// Hub quest board cards (thumbnail + title + goal + rank); **560pt** phone, **800pt** iPad regular so long titles don’t stack like a phone column.
    case questCardList
    /// Prologue teaching stacks — currently matches ``reading``; future target **680–760pt** on iPad per design review.
    case lesson
    /// Active encounter HUD and playfield chrome — currently matches ``reading``; future **760–1000pt** or full-bleed per mechanic.
    case playfield
    /// Primary/secondary CTA stacks — matches ``reading`` until actions get an independent cap tied to parent content.
    case actions
}

/// Horizontal metrics for scroll content over full-bleed quest art (phone, iPad, Dungeon result gutters).
///
/// Prefer the **role-aware** APIs. Legacy ``scrollHorizontalPadding(containerWidth:horizontalSizeClass:gameKind:)`` and
/// ``readingColumnMaxWidth(containerWidth:horizontalSizeClass:horizontalPadding:)`` delegate to ``reading``.
enum QuestPaintContentMetrics {

    // MARK: - Role-aware API

    /// Horizontal inset so a centered content column matches the layout role’s target width on canvas.
    ///
    /// - Parameters:
    ///   - role: ``QuestLayoutRole`` (hub cards use ``QuestLayoutRole/questCardList``).
    ///   - containerWidth: Pass ``GeometryProxy/size.width`` (or equivalent).
    ///   - horizontalSizeClass: From the SwiftUI environment.
    ///   - gameKind: When ``GameKind/scrollHunt``, adds extra gutter for Dungeon result/readability (reading lineage only).
    static func horizontalPadding(
        role: QuestLayoutRole,
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        gameKind: GameKind?
    ) -> CGFloat {
        let anchor = layoutAnchorWidth(role: role, horizontalSizeClass: horizontalSizeClass)
        let centered = max(0, (containerWidth - anchor) / 2)
        var pad = max(RA11ySpacing.base, centered)
        if horizontalSizeClass == .regular {
            pad = max(pad, RA11ySpacing.xl)
        }
        if appliesScrollHuntGutter(role: role, gameKind: gameKind) {
            pad += RA11ySpacing.md
        }
        return pad
    }

    /// Maximum width of the content column inside ``horizontalPadding``.
    static func contentMaxWidth(
        role: QuestLayoutRole,
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        let cap = contentWidthCap(role: role, horizontalSizeClass: horizontalSizeClass)
        return min(max(containerWidth - horizontalPadding * 2, 0), cap)
    }

    // MARK: - Legacy (delegates to `.reading`)

    /// Outside padding for a scroll column; widens on compact widths and adds ribbon inset for Dungeon results.
    ///
    /// Equivalent to ``horizontalPadding(role:containerWidth:horizontalSizeClass:gameKind:)`` with ``QuestLayoutRole/reading``.
    static func scrollHorizontalPadding(
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        gameKind: GameKind?
    ) -> CGFloat {
        horizontalPadding(
            role: .reading,
            containerWidth: containerWidth,
            horizontalSizeClass: horizontalSizeClass,
            gameKind: gameKind
        )
    }

    /// Maximum width of the reading column inside horizontal padding (keeps line length comfortable on iPad).
    ///
    /// Equivalent to ``contentMaxWidth(role:containerWidth:horizontalSizeClass:horizontalPadding:)`` with ``QuestLayoutRole/reading``.
    static func readingColumnMaxWidth(
        containerWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        contentMaxWidth(
            role: .reading,
            containerWidth: containerWidth,
            horizontalSizeClass: horizontalSizeClass,
            horizontalPadding: horizontalPadding
        )
    }

    // MARK: - Private

    /// Width used only to derive symmetric side padding (center column on wide canvas).
    private static func layoutAnchorWidth(role: QuestLayoutRole, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        let isRegular = horizontalSizeClass == .regular
        switch role {
        case .reading:
            return isRegular ? 640 : 560
        case .questCardList:
            return isRegular ? 840 : 560
        case .lesson, .playfield, .actions:
            return isRegular ? 640 : 560
        }
    }

    private static func contentWidthCap(role: QuestLayoutRole, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        let isRegular = horizontalSizeClass == .regular
        switch role {
        case .reading:
            return isRegular ? 620 : 560
        case .questCardList:
            return isRegular ? 800 : 560
        case .lesson, .playfield, .actions:
            return isRegular ? 620 : 560
        }
    }

    private static func appliesScrollHuntGutter(role: QuestLayoutRole, gameKind: GameKind?) -> Bool {
        guard gameKind == .scrollHunt else { return false }
        switch role {
        case .reading, .lesson, .actions:
            return true
        case .questCardList, .playfield:
            return false
        }
    }
}

// MARK: - Mockup-aligned typography (Dynamic Type)

/// Fantasy mockup roles: serif display lines, warm neutrals, gold captions.
///
/// ## VoiceOver
/// VoiceOver reads the underlying ``Text`` string (and any ``AccessibilityTraits`` you add on the view).
/// Drop shadows here are **visual-only** and do not affect spoken output. Pair colored captions (``captionGold``)
/// with explicit wording—not color alone—so meaning is clear when users don’t perceive hue.
///
/// Prefer **one logical label per focusable unit**: when you use ``AccessibilityElement`` grouping
/// (e.g. ``accessibilityElement(children: .combine)``), ensure the combined
/// ``accessibilityLabel`` includes every string the sighted user needs, in a sensible order.
///
/// ## Dynamic Type
/// Body/meta roles use ``Font/ra11yBody`` / ``Font/ra11ySubheadline`` / ``Font/ra11yCaption`` so they track
/// the user’s content size. Serif display roles use ``Font/system(_:design:)`` text styles (e.g. ``TextStyle/largeTitle``),
/// which also scale. Validate at **extra-extra-large** sizes: wrapping, clipping, and navigation bar height.
///
/// ## Reduce Transparency / Increase Contrast
/// ``materialCard*`` roles are meant for ``Material`` surfaces; with **Reduce Transparency** on, materials
/// become more opaque—re-verify contrast. **Increase Contrast** can flatten perceived separation that shadows
/// provide; if copy feels thin, bump weight or opacity in a follow-up pass (do not rely on shadow alone for meaning).
///
/// **Suitability:** This modifier is appropriate for **styled static copy** on painted or card surfaces. It does not
/// replace per-screen **hints**, **identifiers**, **actions**, or **heading** traits—you must still add those where product spec requires.
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
    ///
    /// - Note: Does not set VoiceOver labels—keep ``Text`` literals accurate and add
    ///   ``View/accessibilityHint(_:)-6yw3c`` / grouping at the container when the UX needs it.
    func questPaintReadableText(_ role: QuestPaintReadableTextRole) -> some View {
        modifier(QuestPaintReadableTextModifier(role: role))
    }
}
