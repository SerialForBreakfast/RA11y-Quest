# Completed Tasks

Date: 2026-07-04

This file archives completed checklist items moved out of active task trackers so
the remaining task files stay focused on unfinished work.

## From `memlog/designRefactorTasks.md`

### Task UI-1 — Add quest layout roles and metrics

- [x] Add `QuestLayoutRole` with roles for `reading`, `questCardList`, `result`, `lesson`, `playfield`, and `actions`.
- [x] Replace or extend `QuestPaintContentMetrics` with role-aware width and horizontal padding APIs.
- [x] Document iPhone and iPad target widths for each role (enum + `QuestPaintContentMetrics` Quick Help table).
- [x] Keep regular-width content centered unless a playfield explicitly needs full bleed (centering unchanged; playfield role reserved).
- [x] Existing screens compile with the new metrics available.
- [x] No screenshot route loses its root accessibility identifier (hub-only migration; other sites still use legacy reading helpers).

### Task UI-2 — Fix iPad hub card layout using the new role

- [x] Move the hub quest list to the `questCardList` layout role.
- [x] Increase iPad card width to avoid short stacked title wrapping (**800pt** column vs **620pt** reading).
- [x] Keep the initial implementation as a single centered list for stable VoiceOver order.
- [x] Keep footer actions aligned with the hub content rhythm (footer unchanged).

### Task UI-3 — Create shared illustrated quest screen scaffold

- [x] Add a reusable `QuestPaintScreen` or equivalent scaffold for illustrated quest surfaces.
- [x] Centralize full-bleed background art, readable scrim, dark color scheme, and role-based scroll column width (per-call-site vertical padding stays on inner content for now).
- [x] Keep quest-specific art selected by the caller.
- [x] Scaffold must not introduce extra focusable elements for background, scrim, or layout containers.
- [x] Scaffold should preserve caller-defined root accessibility identifiers.
- [x] Document expected screen order for content hosted inside the scaffold (see `QuestPaintScreen` Quick Help).
- [x] Pilot call sites: `iOSGameResultView`, `iOSVORequiredView` compile; screenshot routes unchanged at identifier level.
- [x] Decorative art remains hidden from accessibility (scrim; backdrop unchanged from prior pattern).

### Task UI-9 — Align result screen with final layout roles

- [x] Move result layout to role-aware metrics (`QuestLayoutRole/result` + `QuestPaintScreen`; Dungeon keeps `scrollHunt` gutter).
- [x] Ensure summary, skill transfer, gesture reminder, and action stack align to the same content width.

### Tasks 1–7 — Rename scroll zone to "Glyph stream" + trim objective/status/feedback copy

- [x] `Localizable.xcstrings` shipped copy verified matching the target strings for the scroll zone rename, objective trims, scroll status bands, gesture tip card, wrong-target feedback, seal hint, and Lights Off flavor text (Tasks 1–7).
- [x] Optional cleanup: renamed localization key `dungeon.resonance.tip.voFocusOnLane` → `dungeon.resonance.tip.voFocusOnGlyphStream` in `Localizable.xcstrings` and its sole Swift call site (`iOSDungeonResonancePlayView.swift`).

### Task 9 — Tighten timeout and result strings

- [x] `Localizable.xcstrings` shipped copy verified matching target strings for `dungeon.timeout` and `dungeon.results.*`.

### Task 10 — Prologue copy tightening

- [x] `Localizable.xcstrings` shipped copy verified matching target string for `dungeon.explain.lesson.body`.

### Task 8 — Timer 75% key clarity

- [x] Verified no threshold bug in `startTimer`/`announceTimerThreshold` — `pct` is fraction elapsed, not remaining.
- [x] Documentation-only fix already present above `announceTimerThreshold` (`iOSDungeonDescentView.swift`) spelling out elapsed vs. remaining for each threshold; no key rename needed.

### Scope — beyond `Localizable.xcstrings` (Glyph stream rename)

- [x] Swift comments/Quick Help updated to say "Glyph stream" instead of "Moonstone alignment lane": `iOSDungeonDescentView.swift`, `QuestFeedbackProfile.swift`, `QuestFeedbackTypes.swift`, `GameDefinition.swift`.
- [x] Canonical terminology docs updated: `memlog/requirements/Design/CrystalResonance-Terminology.txt`, `DungeonResonanceAssetPipeline.txt`.
- [x] Living QC checklist updated: `memlog/research/CrystalResonance-Asset-And-Scroll-QC.md`.
- [x] `memlog/requirements/Design/VoiceOver-GestureSpell-Vocabulary.md` checked — no old-phrase mentions found, no edit needed.
- [~] `memlog/research/CrystalResonance-VoiceOverScrollProxy-Investigation.md` intentionally left as-is — it's a dated investigation log describing what VoiceOver announced at the time, not living reference copy.
- [x] UITests and screenshot docs checked — no mentions of the old phrase found in `RA11y-iOSUITests/` or `fastlane/`.
