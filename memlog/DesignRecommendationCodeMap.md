# Design Recommendation → Code Map

Date: 2026-04-24  
Companion: [`DesignRecommendationReview.md`](DesignRecommendationReview.md)  
Task tracker: [`designRefactorTasks.md`](designRefactorTasks.md) — **Quest UI System Refactor** (UI-1 … UI-11)

This document maps each major finding and implementation phase in the design review to **concrete Swift files, types, and line-level behavior** in the repo today.

---

## § Screenshot Pass Summary → Routes & Assets

| Reviewed shot | UI test / scene | Primary Swift entry |
|---------------|-----------------|---------------------|
| `01_Hub` | `hubRoot` | `iOSHubView.swift` |
| `04_EnchanterPrologue` | `enchanterPrologue` | `iOSEnchantersTrialView.swift` → `EnchanterPrologueView` |
| `08_EnchanterResult` | `enchanterResult` | `iOSGameResultView.swift` |
| `09_DungeonPrologue` | `dungeonPrologue` | `iOSDungeonDescentView.swift` → `DungeonPrologueView` |
| `10_DungeonL1` | `dungeonL1` | `iOSDungeonDescentView.swift` / play subtree |
| `13_BanishmentPrologue` | `banishmentPrologue` | `iOSBanishmentQuestView.swift` → `prologueBody` |
| `14_BanishmentWardTrap` | `banishmentWardTrap` | `iOSBanishmentQuestView.swift` → trap phases |
| `16_BanishmentResult` | `banishmentResult` | `iOSGameResultView.swift` |

Canonical identifiers: `RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md`, `iOSScreenshotScene.swift`.

---

## Finding 1 — iPad hub narrow card lane

**Review:** Hub card column too narrow; titles wrap while sides are empty.

**Code today (2026-04-24 implementation)**

| Item | Location |
|------|-----------|
| Hub uses **`questCardList` metrics** | `iOSHubView.swift` — `QuestPaintContentMetrics.horizontalPadding(role: .questCardList, …)` and `contentMaxWidth(role: .questCardList, …)`; iPad regular content cap **800pt** (anchor **840pt**). |
| Reading metrics (results, VO gate, first run, basics) | Still `scrollHorizontalPadding` / `readingColumnMaxWidth` → delegate to ``QuestLayoutRole/reading`` (**620pt** cap regular). |
| Caps defined in | `iOSQuestPaintChrome.swift` — `QuestLayoutRole` + `QuestPaintContentMetrics` private helpers `layoutAnchorWidth` / `contentWidthCap`. |

**Remaining manual QA:** locked-card contrast, regenerate `01_Hub` screenshots — **Task UI-2** verify section.

---

## Finding 2 — One reading column for everything

**Review:** Reading, cards, playfields, and actions need **separate** width rules.

**`QuestPaintContentMetrics` call sites (all use the same reading model today)**

| Screen | File | Pattern |
|--------|------|---------|
| Hub | `iOSHubView.swift` | `scrollHorizontalPadding` + `readingColumnMaxWidth`, `gameKind: nil` |
| Game result | `iOSGameResultView.swift` | Same, `gameKind` passed → extra horizontal inset for `.scrollHunt` |
| VO required gate | `iOSVORequiredView.swift` | Same |
| First run | `iOSFirstRunView.swift` | Same |
| Basics sequence | `iOSBasicsSequenceView.swift` | Same |

**Inconsistent ad-hoc widths (not using `QuestPaintContentMetrics`)**

| Surface | File | Regular-width cap / notes |
|---------|------|---------------------------|
| Enchanter prologue | `iOSEnchantersTrialView.swift` — `EnchanterPrologueView` | `contentMaxWidth` **600** (≈L811–L813) |
| Dungeon prologue | `iOSDungeonDescentView.swift` — `DungeonPrologueView` | `frame(maxWidth: … **720**)` (≈L881) |
| Banishment prologue | `iOSBanishmentQuestView.swift` | `prologueColumnMaxWidth` **620 / 560** (≈L753–L755) |
| Banishment trap layout | `iOSBanishmentQuestView.swift` — `BanishmentTrapPlayfieldLayout` | `widthCap` **560 / 480** (≈L1059–L1061) |
| Banishment scored HUD | `iOSBanishmentQuestView.swift` | `scoredHUDMaxWidth` **560** on regular (≈L820–L825) |

**Design fix direction:** `QuestLayoutRole` + role-aware metrics — **Task UI-1**; then migrate call sites per UI-2 … UI-7.

---

## Finding 3 — Prologue scaffolds differ

**Review:** Same user intent; different structure / viewport balance (Banishment spell plate dominates on iPad).

| Quest | Struct / region | File (approx.) |
|-------|-----------------|----------------|
| Enchanter L0 | `EnchanterPrologueView` | `iOSEnchantersTrialView.swift` ≈L791–L907 |
| Crystal L0 | `DungeonPrologueView` | `iOSDungeonDescentView.swift` ≈L854–L986 |
| Banishment | `prologueBody`, `banishmentZScrubSpellPlate` | `iOSBanishmentQuestView.swift` ≈L684–L728 |

Shared pieces already: `QuestVoiceOverGestureSpellPlate` (`iOSQuestVoiceOverSpellPlate.swift`), `questPaintReadableText` roles.

**Design fix direction:** Shared narration/lesson/gesture/practice/action components — **Tasks UI-3, UI-4, UI-5–UI-7**.

---

## Finding 4 — Result screen as model

**Review:** Strongest shared structure; align widths/actions with new roles.

**Code today**

| Piece | File |
|-------|------|
| Backdrop + scrim | `iOSGameResultView.swift` — `QuestPaintAmbientBackdrop`, `QuestPaintReadableScrim` |
| Column width | Same — `QuestPaintContentMetrics` (≈L67–L77) |
| Skill transfer + gesture reminder | Same — `skillTransferCard`, `gestureReminderSection` |
| Actions | `QuestGameResultActionStack` — `iOSQuestStandardActions.swift` |

**Design fix direction:** **Tasks UI-9, UI-10** (alignment + terminology).

---

## Finding 5 — Terminology

**Review:** Standardize Quest / Prologue / Encounter / Result / Tavern / primary actions.

**Primary storage:** `Localizable.xcstrings`  
**Hub example:** `iOSHubView` uses `hub.navigationTitle`, heading keys, rotor string — grep `hub.*` / `result.*` / `level.button.start` / `dungeon.explain.title`.

**Design fix direction:** **Task UI-10** (+ copy tasks in same memlog file for Dungeon glyph stream).

---

## Finding 6 — Tokens vs component boundaries

**Review:** Spacing/radius/color/text roles exist; missing **screen scaffolds** and **shared cards**.

**Token / chrome layer**

| Piece | File |
|-------|------|
| Spacing / radius (core) | `RA11yCore` — e.g. `RA11ySpacing`, `RA11yRadius` (see `RA11yCore/Sources/…`) |
| Ambient + scrim + metrics + text roles | `iOSQuestPaintChrome.swift` |
| Spell plates | `iOSQuestVoiceOverSpellPlate.swift` |
| Standard buttons / result stack | `iOSQuestStandardActions.swift` |

**Design fix direction:** **Tasks UI-3, UI-4** (scaffold + cards with documented a11y contracts).

---

## Recommended system (review) → implementation tasks

| Review proposal | Task ID in `designRefactorTasks.md` |
|-----------------|-------------------------------------|
| `QuestLayoutRole` + role-aware metrics | **UI-1** |
| iPad hub width / `questCardList` | **UI-2** |
| `QuestPaintScreen` (illustrated scaffold) | **UI-3** |
| Shared prologue pieces | **UI-4** |
| Migrate Enchanter / Crystal / Banishment prologues | **UI-5 – UI-7** |
| Encounter HUD chrome | **UI-8** |
| Result alignment | **UI-9** |
| Terminology / `xcstrings` | **UI-10** |
| Screenshots + ScreenAuditKit | **UI-11** |

---

## VoiceOver & accessibility map (review §Accessibility)

| Topic | Where implemented today |
|-------|-------------------------|
| Hub rotor + focus | `iOSHubView.swift` — `AccessibilityRotor`, `@AccessibilityFocusState`, `onChange(voiceOverEnabled)` |
| Banishment escape | `iOSBanishmentQuestView.swift` — `BanishmentTrapOverlay` — `accessibilityAction(.escape, …)` |
| Crystal scroll surface | `iOSDungeonResonancePlayView.swift`, `iOSResonanceVoiceOverScrollProxyRepresentable.swift` (scroll proxy) |
| Result combined summary | `iOSGameResultView.swift` — presenter accessibility |
| Screenshot roots | Per-scene `accessibilityIdentifier` on quest roots (see catalog) |

**Design fix direction:** Component-level contracts documented on new shared views — **UI-1, UI-4, UI-11**.

---

## Phase 1 (review Implementation Plan) — code touch list

First implementation chunk should land **roles + metrics** before migrating screens:

1. **`iOSQuestPaintChrome.swift`** — add `QuestLayoutRole`; extend or replace `QuestPaintContentMetrics` with role-aware APIs (**UI-1**).
2. **`iOSHubView.swift`** — switch hub column to `questCardList` role (**UI-2**).
3. Optional same PR or follow-up: scaffold stub **UI-3**, first card extraction **UI-4** (pilot).

Detailed checkboxes: **designRefactorTasks.md → Task UI-1 → Phase 1 execution tickets**.
