# Design & Copy Refactor Tasks
Date: 2026-04-22
Related: Crystal Resonance (Dungeon Descent), all quests

---

## Context

Two goals:
1. **Rename the scroll zone** — "Moonstone alignment lane" is thematically wrong and mechanically confusing. Replace with **"Glyph stream"** everywhere.
2. **Tighten all copy** — objective cards, VO scroll status, hints, feedback, and flavor text are verbose, redundant, or misdirected. Instructions belong in the gesture tip / hint system, not in the objective or VO status strings.

**Primary edits:** `Localizable.xcstrings`. **Also update** comments and canonical terminology docs that still say “Moonstone alignment lane,” or engineering/onboarding will drift from shipped copy (see **Scope — beyond xcstrings** at the end).

---

## Task 1 — Rename the scroll zone to "Glyph Stream"

**Why:** "Lane" has no thematic fit. "Glyph stream" describes what the player experiences (glyphs flowing past as they scroll) and implies the interaction (you scroll the stream). Instructions referencing the zone by name must all update together or VoiceOver announces the wrong label.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.a11y.scroll.container` → `"Glyph stream"`
- [ ] `dungeon.a11y.scroll.container.hint` → `"Three-finger scroll to move the stream."`
- [ ] `dungeon.resonance.tip.voFocusOnLane` → `"Nothing moving? Swipe to 'Glyph stream' first."`
- [ ] `dungeon.explain.gesture.swipe3` → `"Three fingers: scroll the glyph stream"`
- [ ] `dungeon.explain.practice_tip` → `"Three-finger scroll the glyph stream to practice."`
- [ ] `dungeon.explain.narration` → `"Scroll the glyph stream with three fingers. Align the Moonstone with the orb to seal it."`
- [ ] `dungeon.a11y.explain.lesson` → `"One finger moves focus. Three fingers scroll the glyph stream. Align the Moonstone with the orb."`
- [ ] `voSpell.threeFinger.body` → `"On the glyph stream, three-finger scroll up or down moves the stream."`
- [ ] `voSpell.kicker.scrolling` → e.g. `"Glyph stream"` (drop **Shaft scroll** if the new name is canonical)
- [ ] `voSpell.threeFinger.*` — sweep for “lane” / “alignment lane”; match **Glyph stream**
- [ ] `game.scrollHunt.goal`, `result.skillTransfer.scrollHunt.*`, `basicsSequence.skill.scrollHunt.intro` if they still say “Moonstone lane” / “alignment lane”
- [ ] `dungeon.resonance.hint` → `"Scroll the glyph stream until the Moonstone aligns, then Activate the Seal."`

**Verify:** VoiceOver on → swipe right through elements on L1 → hear "Glyph stream" as the zone label. Confirm the gesture tip card and hint text both say "glyph stream."

---

## Task 2 — Trim objective strings (visual + VoiceOver)

**Why:** Objective cards currently embed gesture instructions. Those live in the gesture tip and hint system. The card should be one phrase: what to do.

**Files:** `Localizable.xcstrings`

Visual objectives:
- [ ] `dungeon.l1.objective.format` → `"Align the Moonstone with the orb."`
- [ ] `dungeon.l2.objective.format` → `"Align the Moonstone — timer running."`
- [ ] `dungeon.l3.objective.format` → `"Align the Moonstone — timer running."`

VoiceOver objectives (currently repeat gesture instructions):
- [ ] `dungeon.a11y.l1.objective.format` → `"Align the Moonstone with the orb."`
- [ ] `dungeon.a11y.l2.objective.format` → `"Align the Moonstone before time runs out."`
- [ ] `dungeon.a11y.l3.objective.format` → `"Align the Moonstone quickly — time is short."`

**Verify:** On each level, VoiceOver reads the objective card and announces only the task — no gesture instructions embedded in the read.

---

## Task 3 — Fix scroll status (announced after every 3-finger swipe)

**Why:** Current format is "Moonstone. Crystal orb, faint resonance." The "Crystal orb," prefix repeats on every swipe announcement — it adds nothing after the first time. Replace with action-oriented band labels.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.resonance.a11y.orb.far` → `"Far — keep scrolling"`
- [ ] `dungeon.resonance.a11y.orb.warm` → `"Getting warmer"`
- [ ] `dungeon.resonance.a11y.orb.near` → `"Almost aligned"`
- [ ] `dungeon.resonance.a11y.orb.locked` → `"Aligned — seal it"`

**Verify:** VoiceOver on → scroll the glyph stream → hear "Moonstone. Aligned — seal it." not "Moonstone. Crystal orb, aligned, ready to seal resonance."

---

## Task 4 — Fix gesture tip card (in-game, L1)

**Why:** The third line is too long and must match Task 1 zone naming.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.explain.gesture.swipe3u` → `"Aligned? Seal button appears below."`
- [ ] Zone tip line: same string as Task 1 (`dungeon.resonance.tip.voFocusOnLane`).

**Verify:** Gesture tip card on L1 reads cleanly in three short lines.

**Optional cleanup:** Rename localization key `voFocusOnLane` → `voFocusOnGlyphStream` in code + catalog when you touch that string (reduces future confusion).

---

## Task 5 — Fix wrong-target feedback and not-reachable text

**Why:** Both strings are verbose and one gives a directional hint that can be wrong.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.feedback.non_target` → `"Not the Moonstone. Keep scrolling."`
- [ ] `dungeon.target.notReachable` → `"Moonstone not aligned yet."` *(drop "too deep" / "scroll down" — Moonstone can be above or below)*

**Verify:** Tap a decoy → hear "Not the Moonstone. Keep scrolling." — Seal button disabled → status shows "Moonstone not aligned yet."

---

## Task 6 — Trim seal button hint

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.resonance.seal.hint` → `"Seals when the Moonstone is aligned."`

---

## Task 7 — Fix Lights Off flavor text

**Why:** Current text is pure instruction with no atmosphere.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.lightsOff.flavor` → `"Darkness falls. Navigate by sound alone."`

**Verify:** L3 lights-off flavor card shows the new text.

---

## Task 8 — Timer 75% key (✅ logic verified — rename for clarity optional)

**Why:** The *string key* says `75pct` but the code fires at **75% of time elapsed** (= **25% time left**). That matches copy like **"Quarter time left."** There is no threshold bug in `startTimer` today.

**Verified behavior** (`iOSDungeonDescentView.swift`): `pctElapsed >= 0.75` → `announceTimerThreshold(..., 0.75)` → `dungeon.a11y.timer.75pct`.

**Suggested improvements (pick one):**
- [ ] **Documentation only:** Add a one-line comment above `announceTimerThreshold` or next to the `0.75` branch: *“Announced when ~25% of time remains.”*
- [ ] **Or** rename the localization key to something like `dungeon.a11y.timer.quarterRemaining` and update call sites (avoids the next reader misreading “75pct” as “75% left”).

**Also note:** Enchanter uses **`simon.a11y.timer.75pct`** with the *same* elapsed-fraction pattern — if you rename dungeon keys for clarity, consider matching Enchanter for consistency.

**Verify:** L3 (45s): at ~33.75s elapsed, hear the quarter-remaining line once; at 50% / 25% elapsed, hear the other thresholds.

---

## Task 9 — Tighten timeout and result strings

**Product note:** These lines add back **theme** (gate, shaft, crystal). That’s fine if the goal is *flavor on results* while keeping *instructional* copy terse elsewhere. If you want maximum plainness everywhere, keep shorter defeat/pass strings instead.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.timeout` → `"Time's up. The gate sealed."`
- [ ] `dungeon.results.legendary` → `"Flawless. The crystal answers you."`
- [ ] `dungeon.results.skilled` → `"Well done. The shaft yields."`
- [ ] `dungeon.results.novice` → `"Sealed. The crystal tested you — and you endured."`
- [ ] `dungeon.results.defeated` → `"The gate sealed. Rest, then try again."`

---

## Task 10 — Prologue copy tightening

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.explain.lesson.body` → `"Practice three-finger scrolling below."`
- [ ] `dungeon.explain.narration` → covered in Task 1

**Verify:** Prologue screen reads cleanly without redundant spell-card cross-references.

---

## Strings to Leave Unchanged

These are working well — concise, thematic, correct:
- Room names and subtitles (`Entry Hall`, `"Torchlit. Safe."`, etc.)
- Level titles (`"First Attempt"`, `"Rising Challenge"`, `"Timed Trial"`)
- Item names (`"Moonstone"`, `"Ember Shard"`, `"Shadow Glyph"`, `"Sun Sigil"`)
- Countdown sequence (`"One."` … `"Ten seconds."`)
- Button labels (`"Activate the Seal"`, `"Begin Trial"`, `"Continue"`, `"Try Again"`)
- DM label (`"Resonance Guide"`)

---

## Zone Naming Convention (for future quests)

Any quest that requires the user to focus a specific zone to perform a gesture should name that zone:

> `[Thematic noun describing the content] + [spatial or motion word]`

| Quest type | Example zone name |
|-----------|-----------------|
| Crystal Resonance | **Glyph stream** |
| Rhythm/sequence | **Rune beat** / **Spell cadence** |
| Selection grid | **Sigil field** / **Relic array** |
| Path navigation | **Cipher path** / **Rune channel** |

Quests where focus works on individual elements (Banishment, Enchanter's Trial) do not need a named zone.

---

## Scope — beyond `Localizable.xcstrings` (Glyph stream rename)

If **Glyph stream** becomes canonical, grep and update or annotate:

| Area | Examples |
|------|-----------|
| Swift comments / Quick Help | `iOSDungeonDescentView.swift`, `iOSDungeonResonancePlayView.swift`, `DungeonRoom` |
| RA11yCore | `GameDefinition.swift`, `QuestFeedbackProfile.swift`, `QuestFeedbackTypes.swift` |
| Requirements / research | `memlog/requirements/Design/CrystalResonance-Terminology.txt`, `DungeonResonanceAssetPipeline.txt`, `memlog/research/CrystalResonance-*.md` |
| Related product doc | `memlog/requirements/Design/VoiceOver-GestureSpell-Vocabulary.md` (spell card examples) |

UITests and screenshot docs that quote the old phrase should be updated when copy ships.

---

# Quest UI System Refactor Tasks

Date: 2026-04-24
Related: `memlog/DesignRecommendationReview.md`, all screenshot-covered quest screens

## Context

The iPad hub screenshot exposed a broader design-system issue: hub cards, prologues, encounters, and result screens do not share one consistent adaptive layout and VoiceOver interaction contract. The goal of this workstream is to create reusable UI primitives that produce consistent screenshots and reliable VoiceOver behavior across iPhone small, iPhone large, and iPad.

Design goals:

- Standardize responsive layout roles for reading content, hub cards, lessons, playfields, and actions.
- Make VoiceOver behavior a component-level contract, not a per-screen afterthought.
- Preserve quest-specific mechanics while unifying surrounding chrome, terminology, and action patterns.
- Keep screenshot automation deterministic and aligned with `ScreenshotRouteCatalog.md`.

## Task UI-1 — Add quest layout roles and metrics

**Why:** The current shared reading-column metric is too narrow for iPad hub cards and too generic for playfields. Design surfaces need role-specific width and padding rules.

**Files:**
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift`
- `RA11yCore/Sources/RA11yCore/Design/RA11yTokens.swift` if shared token additions are needed

**Work:**
- [ ] Add `QuestLayoutRole` with roles for `reading`, `questCardList`, `lesson`, `playfield`, and `actions`.
- [ ] Replace or extend `QuestPaintContentMetrics` with role-aware width and horizontal padding APIs.
- [ ] Document iPhone and iPad target widths for each role.
- [ ] Keep regular-width content centered unless a playfield explicitly needs full bleed.

**VoiceOver requirements:**
- [ ] Document that layout role changes require rechecking VoiceOver order and Dynamic Type.
- [ ] Ensure role metrics do not cause focusable controls to clip or move off-screen at large Dynamic Type sizes.

**Verify:**
- [ ] Existing screens compile with the new metrics available.
- [ ] No screenshot route loses its root accessibility identifier.

## Task UI-2 — Fix iPad hub card layout using the new role

**Why:** The iPad hub card lane currently behaves like a narrow phone column. Quest cards need enough width for title, thumbnail, description, status, and lock state.

**Files:**
- `RA11y-iOS/RA11y-iOS/Hub/iOSHubView.swift`
- `RA11y-iOS/RA11y-iOS/Hub/iOSQuestCardView.swift`
- `RA11y-iOS/RA11y-iOS/Hub/iOSQuestCardInfoView.swift`

**Work:**
- [ ] Move the hub quest list to the `questCardList` layout role.
- [ ] Increase iPad card width to avoid short stacked title wrapping.
- [ ] Keep the initial implementation as a single centered list for stable VoiceOver order.
- [ ] Recheck locked-card opacity, contrast, and readability.
- [ ] Keep footer actions aligned with the hub content rhythm.

**VoiceOver requirements:**
- [ ] Preserve the custom "Quests" rotor.
- [ ] Preserve predictable focus movement to the first quest card when VoiceOver is enabled.
- [ ] Keep each quest card as one understandable accessibility element with title, goal, status/rank, and lock requirement.
- [ ] Ensure locked cards communicate both locked state and unlock requirement without relying on color or lock icon alone.

**Verify:**
- [ ] Regenerate `01_Hub` for iPhone small, iPhone large, and iPad.
- [ ] iPad `01_Hub` no longer wraps major titles into narrow stacked fragments.
- [ ] VoiceOver swipe order remains: title, orientation, heading, quest cards, basics/help footer.

## Task UI-3 — Create shared illustrated quest screen scaffold

**Why:** Prologues and results repeatedly hand-roll full-bleed art, scrims, safe-area behavior, and content width logic.

**Files:**
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift`
- Existing quest screens as call sites after the scaffold lands

**Work:**
- [ ] Add a reusable `QuestPaintScreen` or equivalent scaffold for illustrated quest surfaces.
- [ ] Centralize full-bleed background art, readable scrim, dark color scheme, safe-area handling, vertical padding, and role-based content width.
- [ ] Support scroll content and fixed action areas without forcing every screen into one layout.
- [ ] Keep quest-specific art selected by the caller.

**VoiceOver requirements:**
- [ ] Scaffold must not introduce extra focusable elements for background, scrim, or layout containers.
- [ ] Scaffold should preserve caller-defined root accessibility identifiers.
- [ ] Document expected screen order for content hosted inside the scaffold.

**Verify:**
- [ ] A small pilot call site compiles and preserves screenshot capture behavior.
- [ ] Decorative art remains hidden from accessibility.

## Task UI-4 — Create shared prologue components

**Why:** Enchanter, Crystal Resonance, and Banishment teach gestures with the same intent but different structure, spacing, and action placement.

**Files:**
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift`
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestVoiceOverSpellPlate.swift`
- New OS-prefixed design file if the component set is large, for example `iOSQuestPrologueComponents.swift`

**Work:**
- [ ] Add `QuestNarrationCard`.
- [ ] Add `QuestLessonCard`.
- [ ] Add `QuestGestureRows` or a compact gesture-list component.
- [ ] Add `QuestPracticeCard` support for optional practice gates.
- [ ] Add `QuestPrologueActionBar` using standard primary action styling.
- [ ] Define a prologue content order: title, narration, lesson, gesture teaching card, practice if required, primary action.

**VoiceOver requirements:**
- [ ] Lesson and narration cards combine related copy into logical VoiceOver elements.
- [ ] Gesture cards expose a clear label and hint, and hide decorative gesture art.
- [ ] Practice gates speak disabled/enabled state and explain what unlocks the primary action.
- [ ] Primary action hints explain the result of activation.

**Verify:**
- [ ] Components have doc comments describing grouping behavior, labels/hints responsibility, and focus expectations.
- [ ] Components scale cleanly with Dynamic Type.

## Task UI-5 — Refactor Enchanter prologue to shared scaffold

**Why:** Enchanter is the clearest current prologue pattern and should be the first migration target.

**Files:**
- `RA11y-iOS/RA11y-iOS/Games/iOSEnchantersTrialView.swift`
- `RA11y-iOS/RA11y-iOS/Localizable.xcstrings` if terminology changes

**Work:**
- [ ] Replace hand-rolled prologue layout with shared scaffold/components.
- [ ] Keep DM narration, lesson, linear navigation spell plate, gesture rows, and primary action.
- [ ] Standardize primary action text if product terminology decision changes from "Begin Trial" to "Begin Quest".

**VoiceOver requirements:**
- [ ] Preserve swipe-right/left then double-tap teaching.
- [ ] Verify prologue order: title, narration, lesson, gesture card, gesture rows if exposed, primary action.
- [ ] Ensure decorative gesture rows are either hidden or represented by equivalent spoken lesson copy.

**Verify:**
- [ ] Regenerate `04_EnchanterPrologue` for all screenshot sizes.
- [ ] Run focused VoiceOver/manual audit for prologue swipe order.

## Task UI-6 — Refactor Crystal Resonance prologue to shared scaffold

**Why:** Crystal Resonance adds the required practice scroll gate and is the best test of whether the shared prologue model supports interactive teaching.

**Files:**
- `RA11y-iOS/RA11y-iOS/Games/iOSDungeonDescentView.swift`
- `RA11y-iOS/RA11y-iOS/Localizable.xcstrings`

**Work:**
- [ ] Move narration, lesson, spell plate, gesture rows, practice zone, and begin action into shared prologue structure.
- [ ] Preserve the practice-scroll requirement before the begin action enables.
- [ ] Align terminology with the Crystal Resonance copy tasks above, especially if "Glyph stream" becomes canonical.

**VoiceOver requirements:**
- [ ] Practice scroll surface has a clear label and hint.
- [ ] Disabled begin action communicates what the user must do first.
- [ ] Preserve the single reliable scroll surface model.

**Verify:**
- [ ] Regenerate `09_DungeonPrologue` for all screenshot sizes.
- [ ] VoiceOver can complete practice by focusing the scroll surface and three-finger scrolling.

## Task UI-7 — Refactor Banishment prologue to shared scaffold

**Why:** Banishment currently feels visually separate from the other prologues and the large gesture plate can dominate the first viewport.

**Files:**
- `RA11y-iOS/RA11y-iOS/Games/iOSBanishmentQuestView.swift`
- `RA11y-iOS/RA11y-iOS/Localizable.xcstrings`

**Work:**
- [ ] Use the shared prologue scaffold while preserving authored Z gesture art.
- [ ] Restore a complete visible hierarchy: quest title, body/narration, instruction, gesture plate, primary action.
- [ ] Align the primary action label with the product terminology decision.

**VoiceOver requirements:**
- [ ] Preserve the two-finger scrub teaching.
- [ ] Ensure gesture art is decorative and the spoken instruction fully explains the action.
- [ ] Preserve the later trap `accessibilityAction(.escape)` behavior.

**Verify:**
- [ ] Regenerate `13_BanishmentPrologue` for all screenshot sizes.
- [ ] Prologue title/body/action are discoverable without sight.

## Task UI-8 — Extract shared encounter chrome

**Why:** Active quest screens should share objective, status, timer, mistake, retry, and continue treatments while keeping their unique mechanics.

**Files:**
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift`
- `RA11y-iOS/RA11y-iOS/Games/iOSEnchantersTrialView.swift`
- `RA11y-iOS/RA11y-iOS/Games/iOSDungeonResonancePlayView.swift`
- `RA11y-iOS/RA11y-iOS/Games/iOSBanishmentQuestView.swift`

**Work:**
- [ ] Add shared objective card component.
- [ ] Add shared timer/mistake HUD component.
- [ ] Add shared status/feedback card component.
- [ ] Add shared continue/retry action placement.
- [ ] Apply to Enchanter and Crystal Resonance first.
- [ ] Apply compatible pieces to Banishment without flattening the trap surface.

**VoiceOver requirements:**
- [ ] Objective appears near the beginning of swipe order.
- [ ] Timers and mistake counts have spoken equivalents.
- [ ] Status announcements are meaningful and not overly repetitive.
- [ ] Active playfield elements remain reachable when the mechanic requires individual choices.
- [ ] Crystal Resonance decorative lane elements remain ignored by VoiceOver.
- [ ] Banishment trap surface keeps `accessibilityAction(.escape)`.

**Verify:**
- [ ] Regenerate active encounter screenshots: `05_EnchanterAttempt`, `06_EnchanterRising`, `07_EnchanterTimed`, `10_DungeonL1`, `14_BanishmentWardTrap`, `15_BanishmentTower`.
- [ ] VoiceOver can identify current objective, state, and next available action on each encounter.

## Task UI-9 — Align result screen with final layout roles

**Why:** Result screens are the closest current model for consistency, but should use the same role-based metrics and action alignment as the rest of the system.

**Files:**
- `RA11y-iOS/RA11y-iOS/Results/iOSGameResultView.swift`
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestStandardActions.swift`

**Work:**
- [ ] Move result layout to role-aware metrics.
- [ ] Ensure summary, skill transfer, gesture reminder, and action stack align to the same content width.
- [ ] Keep `Try Again` and `Back to Tavern` consistent across all quest results.

**VoiceOver requirements:**
- [ ] Preserve result order: rank summary, quest-specific flavor, skill transfer, gesture reminder, Try Again, Back to Tavern.
- [ ] Skill transfer must state what was learned and where it applies outside the game.
- [ ] Gesture reminder must match the quest-specific mechanic.

**Verify:**
- [ ] Regenerate `08_EnchanterResult`, `11_DungeonResult`, and `16_BanishmentResult` for all screenshot sizes.
- [ ] Result controls are reachable and hints are useful.

## Task UI-10 — Standardize product terminology

**Why:** "Quest", "Trial", "Tower", "Descent", "Gauntlet", "Begin", and "Continue" currently mix product structure and quest flavor.

**Files:**
- `RA11y-iOS/RA11y-iOS/Localizable.xcstrings`
- `RA11yCore/Sources/RA11yCore/GameCatalog/GameDefinition.swift`
- Screenshot route docs only if visible labels or scene descriptions change

**Work:**
- [ ] Decide whether hub/product structure uses "Quest" or "Trial" as the canonical product term.
- [ ] Keep quest-specific flavor in titles and narration, not primary action grammar.
- [ ] Standardize prologue primary action.
- [ ] Standardize result replay and exit actions.
- [ ] Update VoiceOver labels where visual text remains intentionally stylized.

**VoiceOver requirements:**
- [ ] Spoken labels use clear product language even when visual text is more thematic.
- [ ] Action hints describe outcomes, not just repeat labels.

**Verify:**
- [ ] Sweep screenshots for visible terminology consistency.
- [ ] Sweep VoiceOver strings for mismatched quest/product terms.

## Task UI-11 — Add screenshot and accessibility validation coverage

**Why:** The new design system should stay reliable after future quest work.

**Files:**
- `RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md`
- `RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift`
- `RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift`
- `fastlane/Fastfile`
- `ScreenAuditKit/` if adding visual rules

**Work:**
- [ ] Confirm every screenshot route has a documented root accessibility identifier.
- [ ] Confirm screenshot tests wait on stable root anchors.
- [ ] Consider ScreenAuditKit checks for iPad hub narrow-card regression, margin sanity, and text/button clipping.
- [ ] Add a manual VoiceOver audit checklist per required screenshot scene.

**VoiceOver requirements:**
- [ ] Each route documents the expected initial focus path.
- [ ] Root anchors remain stable across refactors.
- [ ] Screenshot determinism does not bypass meaningful accessibility structure.

**Verify:**
- [ ] Run `utility/validate_screenshot_contract.sh`.
- [ ] Regenerate full screenshot set after substantive UI changes.
- [ ] Run full build/test before declaring the refactor complete.

## Suggested sequencing

1. UI-1: layout roles and metrics.
2. UI-2: iPad hub fix.
3. UI-3 and UI-4: shared scaffold and prologue components.
4. UI-5 through UI-7: migrate prologues one quest at a time.
5. UI-8: shared encounter chrome.
6. UI-9 and UI-10: result alignment and terminology.
7. UI-11: validation hardening.

## Definition of Done

- iPad hub no longer presents a narrow phone-like card lane.
- Hub, prologue, encounter, and result surfaces use shared layout roles where appropriate.
- All reusable quest components document their VoiceOver grouping, label/hint, focus, and identifier expectations.
- Quest-specific VoiceOver mechanics remain intact: hub rotor/focus, Enchanter swipe-and-activate, Crystal scroll surface, Banishment escape action, and result skill transfer.
- All screenshot-covered scenes pass on iPhone small, iPhone large, and iPad.
- `utility/validate_screenshot_contract.sh` passes after any screenshot route changes.
- Full build and test pass after implementation work.
