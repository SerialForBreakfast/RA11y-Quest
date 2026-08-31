# Design & Copy Refactor Tasks
Date: 2026-04-22
Related: Crystal Resonance (Dungeon Descent), all quests

**Index:** Remaining work is summarized in repo root **`Tasks.md`**.
Completed checklist items are archived in `memlog/CompletedTasks.md`.

---

## Context

Two goals:
1. **Rename the scroll zone** — "Moonstone alignment lane" is thematically wrong and mechanically confusing. Replace with **"Glyph stream"** everywhere.
2. **Tighten all copy** — objective cards, VO scroll status, hints, feedback, and flavor text are verbose, redundant, or misdirected. Instructions belong in the gesture tip / hint system, not in the objective or VO status strings.

**Primary edits:** `Localizable.xcstrings`. **Also update** comments and canonical terminology docs that still say “Moonstone alignment lane,” or engineering/onboarding will drift from shipped copy (see **Scope — beyond xcstrings** at the end).

All tasks in this section (1–10, the beyond-xcstrings scope sweep, and Task 8's
timer key clarity) are complete and archived in `memlog/CompletedTasks.md`.

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

**Code map:** Line-by-line mapping from the design review to Swift files and metrics lives in [`memlog/DesignRecommendationCodeMap.md`](DesignRecommendationCodeMap.md).

### Phase 1 execution tickets (from `DesignRecommendationReview.md` § Implementation Plan Phase 1)

Use these as the **first mergeable slices** before prologue migrations. They correspond to **Task UI-1** and optionally small pilots for **UI-3 / UI-4**.

| ID | Deliverable | Done when |
|----|--------------|-----------|
| **P1.1** | Add `QuestLayoutRole` enum (`reading`, `questCardList`, `result`, `lesson`, `playfield`, `actions`) in `iOSQuestPaintChrome.swift`. | Compiles; each case has a one-line doc comment describing purpose + iPad vs iPhone intent. |
| **P1.2** | Add role-aware APIs on `QuestPaintContentMetrics` (e.g. `horizontalPadding(role:containerWidth:sizeClass:gameKind:)` and `contentMaxWidth(role:…)`), encapsulating today’s 640/620 caps for `.reading`. | Existing call sites can keep behavior by passing `.reading` (or thin wrappers delegating to old methods marked deprecated). |
| **P1.3** | Document target width bands in Quick Help (table: role × compact × regular) matching the review’s §“Introduce layout roles” table. | Xcode quick help shows numbers without hunting `DesignRecommendationReview.md`. |
| **P1.4** | Define `.questCardList` numeric targets for regular width (**~760–840pt** initial; tune against `01_Hub` iPad screenshot). | Preview or simulator: Enchanter card title does not wrap like a phone column on iPad. |
| **P1.5** | (Optional same PR as P1.4) Add `QuestPaintScreen` **struct shell** only: parameters for `imageName`, `layoutRole`, `content` builder; applies `QuestPaintAmbientBackdrop` + `QuestPaintReadableScrim` + `preferredColorScheme(.dark)` + role width — **no** call-site migrations yet. | Compiles; doc comment lists VO rules (no extra focusables for backdrop/scrim). |
| **P1.6** | (Optional pilot **UI-4**) Extract **one** shared `QuestNarrationCard` used from `EnchanterPrologueView.dmNarrationCard` and `DungeonPrologueView.dmNarrationCard` only. | Visual parity on Enchanter + Dungeon prologue screenshots; combined VO labels unchanged. |

**Suggested first PR:** P1.1–P1.4 + **Task UI-2** hub migration using `.questCardList`. Defer P1.5–P1.6 if the PR would grow too large.

## Task UI-1 — Add quest layout roles and metrics

**Why:** The current shared reading-column metric is too narrow for iPad hub cards and too generic for playfields. Design surfaces need role-specific width and padding rules.

**Files:**
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift`
- `RA11yCore/Sources/RA11yCore/Design/RA11yTokens.swift` if shared token additions are needed

**Work:**
No remaining implementation work.

**VoiceOver requirements:**
- [ ] Document that layout role changes require rechecking VoiceOver order and Dynamic Type.
- [ ] Ensure role metrics do not cause focusable controls to clip or move off-screen at large Dynamic Type sizes.

**Verify:**
Implementation verification archived in `memlog/CompletedTasks.md`.

## Task UI-2 — Fix iPad hub card layout using the new role

**Why:** The iPad hub card lane currently behaves like a narrow phone column. Quest cards need enough width for title, thumbnail, description, status, and lock state.

**Files:**
- `RA11y-iOS/RA11y-iOS/Hub/iOSHubView.swift`
- `RA11y-iOS/RA11y-iOS/Hub/iOSQuestCardView.swift`
- `RA11y-iOS/RA11y-iOS/Hub/iOSQuestCardInfoView.swift`

**Work:**
- [ ] Recheck locked-card opacity, contrast, and readability (manual QA).

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
- [ ] Support scroll content and fixed action areas without forcing every screen into one layout (fixed chrome variant TBD).

**VoiceOver requirements:**
Completed scaffold VoiceOver requirements are archived in `memlog/CompletedTasks.md`.

**Verify:**
Pilot verification archived in `memlog/CompletedTasks.md`.

## Task UI-4 — Create shared prologue components — code done

**Why:** Enchanter, Crystal Resonance, and Banishment teach gestures with the same intent but different structure, spacing, and action placement.

**Files:**
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift`
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestVoiceOverSpellPlate.swift`
- New OS-prefixed design file if the component set is large, for example `iOSQuestPrologueComponents.swift`

**Work:**
- [x] Add `QuestNarrationCard` (`iOSQuestPrologueComponents.swift`; used by Crystal L0).
- [x] Add `QuestLessonCard` (Enchanter L0).
- [x] Add `QuestDecorativeGestureGuide` (Enchanter L0; decorative, `accessibilityHidden`).
- [x] Add `QuestPracticeCard` support for optional practice gates (Crystal L0).
- [x] Add `QuestPrologueActionBar` using standard primary action styling.
- [x] Document prologue content order in `iOSQuestPrologueComponents.swift` (no generic stack type — quests omit different slots).

**VoiceOver requirements:**
- [x] Narration cards hide the decorative DM icon; body text remains a normal spoken element (`QuestNarrationCard`).
- [x] Lesson cards combine related copy into logical VoiceOver elements (`QuestLessonCard`).
- [x] Decorative gesture rows are hidden; spoken teaching lives on the lesson card or spell plate.
- [x] Practice gates speak disabled/enabled state and explain what unlocks the primary action (`QuestPracticeCard` + disabled `QuestPrologueActionBar`).
- [x] Primary action hints explain the result of activation (`QuestPrologueActionBar`).

**Verify:**
- [x] Shipped components have doc comments describing grouping, labels/hints, and identifiers.
- [ ] Components scale cleanly with Dynamic Type (formal audit pending).

## Task UI-5 — Refactor Enchanter prologue to shared scaffold — code done

**Why:** Enchanter is the clearest current prologue pattern and should be the first migration target.

**Files:**
- `RA11y-iOS/RA11y-iOS/Games/iOSEnchantersTrialView.swift`
- `RA11y-iOS/RA11y-iOS/Localizable.xcstrings` if terminology changes

**Work:**
- [x] Replace hand-rolled prologue layout with `QuestPaintScreen` (role `.lesson`) and shared components.
- [x] Keep DM narration, lesson, linear navigation spell plate, gesture rows, and primary action.
- [ ] Standardize primary action text if product terminology decision changes from "Begin Trial" to "Begin Quest".

**VoiceOver requirements:**
- [x] Decorative gesture rows are `accessibilityHidden`; lesson combined label still carries swipe/double-tap teaching.
- [x] Prologue order: narration, lesson, spell plate, hidden gesture rows, primary action (nav title remains on the container).
- [ ] Preserve swipe-right/left then double-tap teaching (manual VO audit).

**Verify:**
- [ ] Regenerate `04_EnchanterPrologue` for all screenshot sizes.
- [ ] Run focused VoiceOver/manual audit for prologue swipe order.

## Task UI-6 — Refactor Crystal Resonance prologue to shared scaffold — done

**Why:** Crystal Resonance adds the required practice scroll gate and is the best test of whether the shared prologue model supports interactive teaching.

**Files:**
- `RA11y-iOS/RA11y-iOS/Games/iOSDungeonDescentView.swift`
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPrologueComponents.swift` (new — `QuestNarrationCard`, `QuestPracticeCard`, `QuestPrologueActionBar`)
- `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift` (bug fix, see below)

**Work:**
- [x] Move narration, spell plate, practice zone, and begin action into shared prologue components (`QuestNarrationCard`, `QuestPracticeCard`, `QuestPrologueActionBar`), consuming the existing `QuestPaintScreen` scaffold (role `.lesson`) instead of a hand-rolled `GeometryReader`. No separate lesson card in Dungeon's prologue, so `QuestLessonCard`/`QuestGestureRows`/`QuestPracticeCard`-for-Enchanter are deferred to UI-5 when Enchanter migrates.
- [x] Preserve the practice-scroll requirement before the begin action enables (`practiceScrollObserved` still gates `QuestPrologueActionBar.isEnabled` exactly as before).
- [x] Terminology already aligned — Glyph stream rename shipped separately (see Tasks 1–10 above).

**VoiceOver requirements:**
- [x] Practice scroll surface keeps its exact label/hint/identifiers (`dungeon.a11y.scroll.container`, `dungeon.a11y.explain.practice.hint`, `dungeon.practiceZone`, `dungeon.prologue.practiceSection`).
- [x] Disabled begin action still communicates via `dungeon.explain.start.hint`.
- [x] Preserve the single reliable scroll surface model — unchanged, only the surrounding chrome moved to shared components.

**Verify:**
- [x] Full `xcodebuild` succeeds; `RA11yCore` `swift build` succeeds.
- [x] Simulator screenshot of `-screenshotScene dungeonPrologue` visually matches pre-refactor layout (verified iPhone 17e: narration card, gesture lesson card, practice zone with numbered steps, begin button all render correctly with proper margins/wrapping).
- [ ] Regenerate `09_DungeonPrologue` for all screenshot sizes via fastlane (not run this session — only manual simulator screenshot verified).

**Found + fixed while migrating:** `QuestPaintScreen` (`iOSQuestPaintChrome.swift`) had a **pre-existing layout bug** affecting **all 8 call sites** (`iOSGameResultView`, `iOSVORequiredView`, `iOSFirstRunView`, `iOSBasicsSequenceView`, `iOSMagicTapFirstSpellView`, `iOSFirstSpellVoiceOverRequiredView`, `iOSRotorNavigationQuestView`, and now `iOSDungeonDescentView`'s prologue): the `GeometryReader` used for column-width math was a `ZStack` sibling next to unconstrained full-bleed backdrop `Image`s, so `geo.size` picked up the artwork's native pixel dimensions instead of the real screen bounds — every screen using this scaffold rendered text unwrapped and clipped on both edges. Fixed by making `GeometryReader` the outermost view and giving the backdrop/scrim an explicit `.frame(width:height:)` derived from it. Verified against both the Dungeon prologue and Dungeon result screenshots (before/after).

## Task UI-7 — Refactor Banishment prologue to shared scaffold — code done

**Why:** Banishment currently feels visually separate from the other prologues and the large gesture plate can dominate the first viewport.

**Files:**
- `RA11y-iOS/RA11y-iOS/Games/iOSBanishmentQuestView.swift`
- `RA11y-iOS/RA11y-iOS/Localizable.xcstrings`

**Work:**
- [x] Use the shared prologue scaffold (`QuestPaintScreen`, `.lesson`) while preserving authored Z gesture art.
- [x] Restore a complete visible hierarchy: quest title, body, instruction, gesture plate, primary action (`QuestPrologueActionBar`).
- [ ] Align the primary action label with the product terminology decision.

**VoiceOver requirements:**
- [x] Gesture plate remains `QuestVoiceOverGestureSpellPlate.banishmentZScrubLesson` (spoken instruction unchanged).
- [x] Preserve the later trap `accessibilityAction(.escape)` behavior (not touched this slice).
- [ ] Preserve the two-finger scrub teaching (manual VO audit).

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
- External **`ScreenAuditKit`** ([`SerialForBreakfast/ScreenAuditKit`](https://github.com/SerialForBreakfast/ScreenAuditKit)) only when extending validation rules — not required for RA11y-only route/catalog work (`AGENTS.md` for CLI wiring)

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
