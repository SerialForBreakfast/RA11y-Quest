# VoiceOver gesture “spell” vocabulary & shared quest chrome

**Copy pass (Apr 2026):** Crystal Resonance / `dungeon.*` strings in `Localizable.xcstrings` were tightened so prologue narration + lesson point to the spell card instead of repeating the full gesture paragraph; hub goal, Basics intro, skill transfer, and `voSpell.*` reminders were shortened in the same pass.

This document formalizes how RA11y teaches VoiceOver gestures using a **consistent fantasy metaphor** (spell plates, ward/shaft/pathfinding kickers, wand and hand SF Symbols, optional golden raster art) and ties it to **reusable SwiftUI** in the iOS target.

**Implementation (code):**

- ``QuestVoiceOverGestureSpellPlate`` — `RA11y-iOS/RA11y-iOS/Design/iOSQuestVoiceOverSpellPlate.swift`
- Standard full-width CTAs — `RA11y-iOS/RA11y-iOS/Design/iOSQuestStandardActions.swift` (`QuestStandardPrimaryButton`, `QuestStandardSecondaryButton`, `QuestGameResultActionStack`)
- Typography / paint lane — `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift` (`questPaintReadableText`, backdrops, scrim, metrics)

---

## 1. Design principles

1. **One visual language** — Lesson blocks and result reminders use the same card shell: thin material, gold kicker row (icon + uppercase caption), serif or mockup-readable title, body text, optional catalog illustration.
2. **Metaphor, not decoration** — Icons reinforce the *real* VoiceOver gesture (hand draw, point, wand for banish). Copy must remain accurate; metaphor supports memory.
3. **Spoken parity** — Combined `accessibilityLabel` on each spell plate must include what sighted users see, in sensible order. Decorative illustration is `accessibilityHidden`; the plate is one logical lesson unit.
4. **Teach → practice → remind** — Prologue shows **lesson** layout; post-run shows **compact reminder** under skill transfer; trap/tower flows may reference escape scrub where product requires it.

---

## 2. Gesture catalog (MVP games)

| Spell id (concept) | VoiceOver behaviour | Primary surfaces | Icon / art |
|--------------------|---------------------|------------------|------------|
| **Pathfinding** | One-finger swipe next/previous; double-tap to activate | Enchanter prologue, Find & Focus result reminder | `hand.point.right.fill` |
| **Shaft scroll** | Three-finger vertical scroll inside scrollable regions; one-finger moves focus | Dungeon prologue, Crystal Resonance result reminder | `hand.draw.fill` |
| **Banishing scrub (Z)** | Two-finger Z-shaped escape scrub | Banishment prologue (PNG or vector fallback), Banishment result reminder | `hand.draw.fill` (lesson), `wand.and.stars` (compact reminder) |
| **Rotor** (future) | Two-finger rotate to choose rotor; one-finger up/down to adjust | Hub “Quests” rotor education, future interstitials | TBD (`arrow.triangle.2.circlepath` placeholder) |

Localization keys use the `voSpell.*` prefix where strings are shared; Banishment reuses existing `banishment.prologue.swipeExplainer` for the long Z copy.

---

## 3. Where components must appear

| Surface | Spell plate | Standard CTAs |
|---------|-------------|---------------|
| Game prologues (L0) | ✅ One **lesson** plate per game (Find & Focus, Scroll Hunt, Banishment) | Begin / Start uses `QuestStandardPrimaryButton` when refactored |
| Shared **result** screen | ✅ **Compact reminder** + existing rank banner + skill transfer | ✅ `QuestGameResultActionStack` (Try Again, Back to Tavern, or Continue Basics) |
| VO gate / help sheet | Optional future: single plate or link to spell glossary | — |
| Hub rotor | Future: short rotor spell + link to Basics | — |

---

## 4. Result banners & buttons

- **Rank / metrics banner** — Remains the material “banner” in `iOSGameResultView` (single combined accessibility element).
- **Flavor line** — Optional game-specific text in the dark translucent capsule (existing).
- **Skill transfer card** — Unchanged pedagogical role; precedes gesture reminder.
- **Gesture reminder** — `result.gestureReminder.heading` + `QuestVoiceOverGestureSpellPlate.resultReminder(for:)`.
- **Actions** — Prominent = Try Again / Continue Basics; secondary = Back to Tavern; always full-width, large control, tavern accent on prominent (`QuestStandardPrimaryButton` / `QuestStandardSecondaryButton`).

---

## 5. Future work

- **Rotor spell** — Add `voSpell.rotor.*` strings and a plate preset; surface on hub or first rotor use.
- **Custom raster set** — Optional Z-style illustrations for linear nav and three-finger scroll if design delivers assets (plate already supports `catalogArtName` + fallback).
- **VO Required / mockup** — Align interstitial copy with the same spell components for consistency.

---

## 6. Validation

- Exercise each prologue with VoiceOver: one focus stop for the spell plate that reads the full lesson.
- Result screen: reminder + skill transfer + actions; no duplicate focus for hidden icons inside the plate.
- Dynamic Type: spell plates use `questPaintReadableText`; verify wrapping at XXL.
