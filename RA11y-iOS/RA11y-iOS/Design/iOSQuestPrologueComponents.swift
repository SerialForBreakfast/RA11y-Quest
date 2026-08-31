import SwiftUI
import RA11yCore

// MARK: - Prologue content order

// Shared building blocks for quest L0 screens hosted in QuestPaintScreen (role .lesson).
// Callers compose a vertical stack; there is no generic stack type because quests omit different slots:
//   Enchanter: narration, lesson, spell plate, decorative gestures, primary action
//   Crystal Resonance: narration, spell plate, practice gate, primary action
//   Banishment: title, body, instructions, spell plate (Z art), primary action
// VoiceOver: each component documents its own grouping. Decorative gesture rows are hidden;
// spoken teaching lives on the lesson card or spell plate.
// Dynamic Type: cards use QuestPaintReadableTextRole styles. Re-check wrapping at
// accessibility extra-extra-large after any prologue migration.

// MARK: - QuestNarrationCard

/// Card background tone for ``QuestNarrationCard``, matching each quest's current DM card treatment.
enum QuestNarrationCardBackground {
    /// `.ultraThinMaterial` (Crystal Resonance).
    case material
    /// Flat translucent black at the given opacity (Enchanter's Trial).
    case translucentBlack(opacity: Double)
}

/// DM narration card: a hidden "DM" icon label plus italic narration body over a card background.
///
/// **VoiceOver:** The icon label is decorative (`.accessibilityHidden`); the narration text speaks
/// as its own element with no combined label override.
struct QuestNarrationCard: View {

    let text: String
    var background: QuestNarrationCardBackground = .material

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Label(String(localized: "dm.label"), systemImage: "scroll.fill")
                .font(.ra11yCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(text)
                .italic()
                .questPaintReadableText(.materialCardBody)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle, in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(Color.ra11yDMBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private var backgroundStyle: AnyShapeStyle {
        switch background {
        case .material:
            AnyShapeStyle(.ultraThinMaterial)
        case .translucentBlack(let opacity):
            AnyShapeStyle(Color.black.opacity(opacity))
        }
    }
}

// MARK: - QuestLessonCard

/// Teaching paragraph following narration: heading plus body combined into one VoiceOver element.
///
/// ## VoiceOver
/// Heading and body merge via `children: .combine`. The caller supplies ``combinedAccessibilityLabel``
/// so spoken copy can be fuller than on-screen text. The heading keeps ``AccessibilityTraits/isHeader``.
///
/// ## Dynamic Type
/// Uses ``QuestPaintReadableTextRole/materialCardTitle`` and ``QuestPaintReadableTextRole/materialCardBody``.
struct QuestLessonCard: View {

    let heading: String
    let bodyCopy: String
    let combinedAccessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(heading)
                .questPaintReadableText(.materialCardTitle)
                .accessibilityAddTraits(.isHeader)

            Text(bodyCopy)
                .questPaintReadableText(.materialCardBody)
        }
        .padding(RA11ySpacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.66), in: .rect(cornerRadius: RA11yRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: RA11yRadius.card)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
    }
}

// MARK: - QuestDecorativeGestureGuide

/// One sight-only gesture caption (SF Symbol name + localized label) for ``QuestDecorativeGestureGuide``.
struct QuestDecorativeGestureRow: Equatable, Sendable {
    let systemSymbolName: String
    let localizedLabel: String
}

/// Vertical list of illustrative gesture captions used in Enchanter L0.
///
/// ## VoiceOver
/// The entire stack is ``accessibilityHidden``. Spoken equivalents must live on ``QuestLessonCard``
/// or ``QuestVoiceOverGestureSpellPlate`` — do not add labels here.
///
/// ## Dynamic Type
/// Caption text uses ``QuestPaintReadableTextRole/bodySupporting``.
struct QuestDecorativeGestureGuide: View {

    let rows: [QuestDecorativeGestureRow]

    var body: some View {
        VStack(spacing: RA11ySpacing.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: RA11ySpacing.md) {
                    Image(systemName: row.systemSymbolName)
                        .font(.ra11yHeadline)
                        .frame(minWidth: 32, alignment: .leading)
                        .foregroundStyle(Color.ra11yCardTertiaryText)
                    Text(row.localizedLabel)
                        .questPaintReadableText(.bodySupporting)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - QuestPracticeCard

/// Gesture practice gate: tip copy plus a numbered-step scroll surface that reports the first
/// nonzero scroll offset, and an optional "ready" confirmation line once that's observed.
///
/// **VoiceOver:** The scroll surface carries the single caller-supplied label/hint/identifier;
/// numbered step rows read as plain body text inside it. The card itself carries its own
/// `containerAccessibilityIdentifier` so UI tests can locate the whole practice section.
struct QuestPracticeCard: View {

    let tipText: String
    let stepTexts: [String]
    let scrollAccessibilityLabel: String
    let scrollAccessibilityHint: String
    let scrollAccessibilityIdentifier: String
    let containerAccessibilityIdentifier: String
    let isReady: Bool
    let readyText: String
    let onNonZeroScroll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
            Text(tipText)
                .questPaintReadableText(.materialCardMeta)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: RA11ySpacing.sm) {
                    ForEach(Array(stepTexts.enumerated()), id: \.offset) { _, step in
                        Text(step)
                            .questPaintReadableText(.bodySupporting)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                }
                .padding(RA11ySpacing.sm)
            }
            .frame(minHeight: 96, maxHeight: 130)
            .background(Color.black.opacity(0.35), in: .rect(cornerRadius: RA11yRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: RA11yRadius.card)
                    .strokeBorder(Color.ra11yAccent.opacity(0.55), lineWidth: 1)
            )
            .accessibilityLabel(scrollAccessibilityLabel)
            .accessibilityHint(scrollAccessibilityHint)
            .accessibilityIdentifier(scrollAccessibilityIdentifier)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, offsetY in
                if abs(offsetY) > 2 { onNonZeroScroll() }
            }

            if isReady {
                Text(readyText)
                    .questPaintReadableText(.captionGold)
            }
        }
        .padding(RA11ySpacing.md)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: RA11yRadius.card))
        .accessibilityIdentifier(containerAccessibilityIdentifier)
    }
}

// MARK: - QuestPrologueActionBar

/// Full-width prominent "begin" action for a quest prologue, with a spoken hint, identifier,
/// and an optional disabled gate (e.g. Crystal Resonance's practice-scroll requirement).
struct QuestPrologueActionBar: View {

    let title: String
    let hint: String
    let identifier: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.ra11yAccent)
        .disabled(!isEnabled)
        .accessibilityHint(hint)
        .accessibilityIdentifier(identifier)
    }
}
