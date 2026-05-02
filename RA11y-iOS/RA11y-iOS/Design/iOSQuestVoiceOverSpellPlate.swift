import SwiftUI
import UIKit
import RA11yCore

// MARK: - Layout

/// Visual density for ``QuestVoiceOverGestureSpellPlate`` — lesson cards vs tight result reminders.
enum QuestVoiceOverGestureSpellLayout {
    /// Prologue / trap-adjacent teaching: optional catalog art, serif title, emphasis body.
    case prologueLesson
    /// Post-run reminder under the skill-transfer card: smaller type, no art.
    case resultReminder
}

// MARK: - Spell plate

/// “Spell card” treatment for VoiceOver gestures — matches Banishment’s golden kicker, hand/wand metaphor,
/// material surface, and combined accessibility (one spoken pass for the lesson block).
///
/// Use catalog art when available (e.g. Z scrub); otherwise the SF Symbol carries the metaphor.
struct QuestVoiceOverGestureSpellPlate: View {

    let layout: QuestVoiceOverGestureSpellLayout
    let kicker: String
    let title: String
    /// Primary teaching copy (visible and included in the combined accessibility label via layout).
    let spellBody: String
    let symbolName: String
    let catalogArtName: String?
    /// When the catalog PNG is absent, host-provided vector art (e.g. Banishment Z stroke) fills the same slot.
    let catalogArtFallback: AnyView?
    let accessibilityLabel: String
    let accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .center, spacing: layout == .prologueLesson ? RA11ySpacing.md : RA11ySpacing.sm) {
            HStack(spacing: RA11ySpacing.sm) {
                Image(systemName: symbolName)
                    .font(layout == .prologueLesson ? .title2 : .title3)
                    .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.38))
                Text(kicker)
                    .textCase(.uppercase)
                    .questPaintReadableText(.captionGold)
                    .tracking(0.4)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)

            if layout == .prologueLesson {
                if let catalogArtName, let zArt = UIImage(named: catalogArtName) {
                    Image(uiImage: zArt)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 5)
                        .accessibilityHidden(true)
                } else if let catalogArtFallback {
                    catalogArtFallback
                        .accessibilityHidden(true)
                }
            }

            Text(title)
                .multilineTextAlignment(.center)
                .questPaintReadableText(layout == .prologueLesson ? .sectionTitle : .materialCardTitle)

            Text(spellBody)
                .multilineTextAlignment(.center)
                .questPaintReadableText(layout == .prologueLesson ? .bodyEmphasis : .materialCardBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(layout == .prologueLesson ? RA11ySpacing.lg : RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: RA11yRadius.card))
        // Avoid compositingGroup before shadow — paired with material on dark quest backdrops it can fringe like grey/checkerboard blocks.
        .shadow(color: .black.opacity(0.22), radius: layout == .prologueLesson ? 16 : 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .modifier(SpellPlateIdentifierModifier(id: accessibilityIdentifier))
    }
}

// MARK: - Presets

extension QuestVoiceOverGestureSpellPlate {

    /// Banishment Z-scrub lesson (uses catalog art when present).
    static func banishmentZScrubLesson(
        catalogArtName: String?,
        catalogArtFallback: AnyView? = nil,
        accessibilityIdentifier: String? = "banishment.prologue.swipeExplainer"
    ) -> QuestVoiceOverGestureSpellPlate {
        QuestVoiceOverGestureSpellPlate(
            layout: .prologueLesson,
            kicker: String(localized: "banishment.prologue.kicker"),
            title: String(localized: "voSpell.zScrub.title"),
            spellBody: String(localized: "banishment.prologue.swipeExplainer"),
            symbolName: "hand.draw.fill",
            catalogArtName: catalogArtName,
            catalogArtFallback: catalogArtFallback,
            accessibilityLabel: String(localized: "banishment.prologue.swipeExplainer.a11y"),
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    /// Enchanter / linear focus: one-finger next–previous and activation.
    static func linearFocusLesson(accessibilityIdentifier: String = "enchanter.prologue.voSpell") -> QuestVoiceOverGestureSpellPlate {
        QuestVoiceOverGestureSpellPlate(
            layout: .prologueLesson,
            kicker: String(localized: "voSpell.kicker.navigation"),
            title: String(localized: "voSpell.linearNav.title"),
            spellBody: String(localized: "voSpell.linearNav.body"),
            symbolName: "hand.point.right.fill",
            catalogArtName: nil,
            catalogArtFallback: nil,
            accessibilityLabel: String(localized: "voSpell.linearNav.a11y"),
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    /// Dungeon moonstone lane: three-finger scrolling.
    static func moonstoneScrollLesson(accessibilityIdentifier: String = "dungeon.prologue.voSpell") -> QuestVoiceOverGestureSpellPlate {
        QuestVoiceOverGestureSpellPlate(
            layout: .prologueLesson,
            kicker: String(localized: "voSpell.kicker.scrolling"),
            title: String(localized: "voSpell.threeFinger.title"),
            spellBody: String(localized: "voSpell.threeFinger.body"),
            symbolName: "hand.draw.fill",
            catalogArtName: nil,
            catalogArtFallback: nil,
            accessibilityLabel: String(localized: "voSpell.threeFinger.a11y"),
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    /// Compact reminder on the shared result screen for the gestures emphasized in each game.
    static func resultReminder(for gameKind: GameKind) -> QuestVoiceOverGestureSpellPlate {
        switch gameKind {
        case .findAndFocus:
            QuestVoiceOverGestureSpellPlate(
                layout: .resultReminder,
                kicker: String(localized: "voSpell.kicker.navigation"),
                title: String(localized: "voSpell.linearNav.title"),
                spellBody: String(localized: "voSpell.linearNav.reminder"),
                symbolName: "hand.point.right.fill",
                catalogArtName: nil,
                catalogArtFallback: nil,
                accessibilityLabel: String(localized: "voSpell.linearNav.reminder.a11y"),
                accessibilityIdentifier: "result.voSpell.findAndFocus"
            )
        case .scrollHunt:
            QuestVoiceOverGestureSpellPlate(
                layout: .resultReminder,
                kicker: String(localized: "voSpell.kicker.scrolling"),
                title: String(localized: "voSpell.threeFinger.title"),
                spellBody: String(localized: "voSpell.threeFinger.reminder"),
                symbolName: "hand.draw.fill",
                catalogArtName: nil,
                catalogArtFallback: nil,
                accessibilityLabel: String(localized: "voSpell.threeFinger.reminder.a11y"),
                accessibilityIdentifier: "result.voSpell.scrollHunt"
            )
        case .banishment:
            QuestVoiceOverGestureSpellPlate(
                layout: .resultReminder,
                kicker: String(localized: "banishment.prologue.kicker"),
                title: String(localized: "voSpell.zScrub.title"),
                spellBody: String(localized: "voSpell.zScrub.reminder"),
                symbolName: "wand.and.stars",
                catalogArtName: nil,
                catalogArtFallback: nil,
                accessibilityLabel: String(localized: "voSpell.zScrub.reminder.a11y"),
                accessibilityIdentifier: "result.voSpell.banishment"
            )
        case .arcanistsTower:
            QuestVoiceOverGestureSpellPlate(
                layout: .resultReminder,
                kicker: String(localized: "voSpell.kicker.rotor"),
                title: String(localized: "voSpell.rotorNav.title"),
                spellBody: String(localized: "voSpell.rotorNav.reminder"),
                symbolName: "circle.grid.2x2.fill",
                catalogArtName: nil,
                catalogArtFallback: nil,
                accessibilityLabel: String(localized: "voSpell.rotorNav.reminder.a11y"),
                accessibilityIdentifier: "result.voSpell.arcanistsTower"
            )
        }
    }
}

private struct SpellPlateIdentifierModifier: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
