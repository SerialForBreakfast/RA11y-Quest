# RA11y — Remaining Tasks

**Purpose:** Explicit, checkboxed index of **approved remaining work** in this monorepo. Deep checklists stay in the canonical trackers below; update those first, then mirror status here.

Completed items live in [`memlog/CompletedTasks.md`](memlog/CompletedTasks.md).

---

## Legend

| Marker | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Done |

---

## Canonical trackers

| Workstream | File |
|------------|------|
| Quest UI refactor + remaining Crystal/Banishment UI | [`memlog/designRefactorTasks.md`](memlog/designRefactorTasks.md) |
| Completed archive | [`memlog/CompletedTasks.md`](memlog/CompletedTasks.md) |
| Screenshot automation contract | [`AGENTS.md`](AGENTS.md) — Screenshot Automation Contract |
| Screenshot + screen-audit workflow | [`memlog/research/ScreenshotAndScreenAudit-GoldenPath.md`](memlog/research/ScreenshotAndScreenAudit-GoldenPath.md) |
| ScreenAuditKit (external repo) | [`https://github.com/SerialForBreakfast/ScreenAuditKit`](https://github.com/SerialForBreakfast/ScreenAuditKit) — historical RA11y notes in [`memlog/research/ScreenAuditKit-Workstream.md`](memlog/research/ScreenAuditKit-Workstream.md) |

---

## Milestones (`README.md`)

- [x] M0 — Infrastructure, CI, Swift package setup
- [x] M1 — Core models
- [x] M2 — VoiceOver gating
- [x] M3 — Hub UI
- [x] M4 — First-run basics sequence
- [x] M5 — The Enchanter's Trial
- [~] M6 — Crystal Resonance / Dungeon Descent refinement (copy complete; remaining UI/screenshot regen)
- [~] M7 — The Banishment (review / audit + prologue scaffold)
- [~] M8 — Screenshot automation + ScreenAudit workflow

---

## M6 — Crystal Resonance copy

Shipped and archived in `memlog/CompletedTasks.md` (Tasks 1–10 + beyond-xcstrings sweep). Remaining Crystal work is **UI-6 screenshot regen** and later **UI-8** encounter chrome.

- [x] Glyph stream rename + objective/status/feedback copy
- [x] Timeout, result, prologue copy
- [x] Timer threshold docs
- [ ] Fastlane regen of Crystal prologue `09_DungeonPrologue` (all sizes) after UI-6 scaffold (see UI-6)

---

## Quest UI system refactor (`UI-1` … `UI-11`)

**Order:** UI-1 → UI-2 → UI-3 + UI-4 → UI-5…7 → UI-8 → UI-9 + UI-10 → UI-11

### UI-1 — Layout roles & metrics — implementation done

- [x] `QuestLayoutRole` + role-aware `QuestPaintContentMetrics` (`iOSQuestPaintChrome.swift`)
- [ ] Recheck VoiceOver order and Dynamic Type after any future role change
- [ ] Confirm large Dynamic Type does not clip focusables on hub / prologue / result

### UI-2 — iPad hub (`questCardList`) — implementation done; QA remaining

- [x] Hub uses `questCardList` (~800pt iPad column)
- [ ] Manual QA: locked-card opacity, contrast, readability
- [ ] VO: “Quests” rotor; first-card focus; combined card labels; locked state without color-only
- [ ] Regenerate `01_Hub` (iPhone small, iPhone large, iPad)
- [ ] Confirm iPad titles do not wrap like a phone column

### UI-3 — `QuestPaintScreen` scaffold — implementation done; one variant remaining

- [x] Full-bleed art + scrim + dark scheme + role-based column (GeometryReader-outer fix shipped with UI-6)
- [ ] Optional fixed-action + scroll-body variant (defer until a screen needs it)

### UI-4 — Shared prologue components — code done; DT audit remaining

Shipped in `RA11y-iOS/RA11y-iOS/Design/iOSQuestPrologueComponents.swift`:

- [x] `QuestNarrationCard`
- [x] `QuestPracticeCard`
- [x] `QuestPrologueActionBar`
- [x] `QuestLessonCard` (Enchanter L0)
- [x] `QuestDecorativeGestureGuide` (Enchanter L0)
- [x] Documented prologue content order (file header; no generic stack type)
- [ ] Dynamic Type torture-test pass across prologue stacks

### UI-5 — Enchanter prologue on shared scaffold — code done; screenshots remaining

- [x] Replace hand-rolled `GeometryReader` with `QuestPaintScreen` + `.lesson` + shared components
- [x] Keep narration, lesson, spell plate, decorative gestures, primary action
- [ ] Align primary label with UI-10 if terminology changes
- [x] Decorative gesture rows hidden; spoken copy on lesson card
- [ ] VO: swipe teaching order (manual audit)
- [ ] Regenerate `04_EnchanterPrologue` (all sizes)

### UI-6 — Crystal prologue on shared scaffold — code done; screenshots remaining

- [x] `QuestPaintScreen` + `.lesson` + `QuestNarrationCard` / `QuestPracticeCard` / `QuestPrologueActionBar`
- [x] Practice-scroll gate still disables Begin until scroll observed
- [ ] Fastlane regen `09_DungeonPrologue` (all sizes)

### UI-7 — Banishment prologue — code done; screenshots remaining

- [x] Shared `QuestPaintScreen` + `QuestPrologueActionBar`; keep authored Z gesture art
- [x] Visible hierarchy: title, body, instructions, gesture plate, primary action
- [ ] Align primary label with UI-10
- [x] Trap `.escape` not touched (later phases)
- [ ] VO: two-finger scrub teaching (manual audit)
- [ ] Regenerate `13_BanishmentPrologue`

### UI-8 — Encounter chrome

- [ ] Shared objective / timer HUD / status / retry+continue
- [ ] Apply Enchanter + Crystal first; compatible Banishment pieces second
- [ ] Regen `05_EnchanterAttempt`, `06_EnchanterRising`, `07_EnchanterTimed`, `10_DungeonL1`, `14_BanishmentWardTrap`, `15_BanishmentTower`
- [ ] VO: objective early; timers/mistakes spoken; Crystal lane deco ignored; Banishment `.escape`

### UI-9 — Results — metrics done; copy/VO remaining

- [x] `QuestLayoutRole.result` + `QuestPaintScreen` (Dungeon keeps scroll-hunt gutter)
- [ ] Consistent `Try Again` / `Back to Tavern` across quests
- [ ] VO: rank → flavor → skill transfer → gesture reminder → CTAs
- [ ] Regen `08_EnchanterResult`, `11_DungeonResult`, `16_BanishmentResult`

### UI-10 — Product terminology

- [ ] Decide canonical product term (Quest vs Trial)
- [ ] Standardize prologue primary + result actions
- [ ] VO labels where visual text stays thematic
- [ ] Update screenshot/catalog copy only if visible labels change

### UI-11 — Validation hardening

- [ ] Every route documents root AX id + initial focus path in `ScreenshotRouteCatalog.md`
- [ ] UI tests wait on stable anchors
- [ ] Optional ScreenAudit rules (iPad hub regression, margins, clipping) via **external** `screenaudit` CLI
- [ ] Manual VO checklist per scene
- [ ] `utility/validate_screenshot_contract.sh` after route edits
- [ ] Full screenshot regen after large UI pass
- [ ] `utility/build_and_test.sh` green before closing the refactor

---

## M8 — Screenshot automation & ScreenAudit (RA11y)

- [~] Contracts, route catalog, Fastlane, `utility/validate_screen_audit.sh` operational (see `AGENTS.md`)
- [ ] Keep the four screenshot-contract files in lockstep on every route change
- [ ] Remaining ScreenAuditKit reporter/CI items (JUnit/SARIF, extra CI docs) belong in **SerialForBreakfast/ScreenAuditKit**, not this repo

---

## First-run — Magic Tap First Spell

Code and screenshot routes exist (`iOSFirstRunView`, `iOSMagicTapFirstSpellView`, scenes `17`–`20`). Remaining is product polish vs the GameSpec, not a missing surface.

- [x] First-spell routing before Basics
- [x] Deterministic screenshots (entry, VO gate, ready, success)
- [ ] Close remaining GameSpec / design-ticket deltas if any after a spec re-read

---

## Documentation hygiene

- [x] ScreenAuditKit and NativeUIAuditKit are **external** (not vendored)
- [ ] Keep this file, `README.md` Status, and `memlog/designRefactorTasks.md` in sync after each slice

---

## Parked (not active RA11y backlog)

| Item | Notes |
|------|--------|
| Bard’s Interrupt / Magic Tap mastery quest | [`memlog/MagicTap-BardsInterrupt-Tasks.md`](memlog/MagicTap-BardsInterrupt-Tasks.md) |
| NativeUIAuditKit adoption | [`https://github.com/SerialForBreakfast/NativeUIAuditKit`](https://github.com/SerialForBreakfast/NativeUIAuditKit) — do not install until Phase 6 |

---

## Maintenance

After closing a slice: update checkboxes here **and** in the cited tracker, shift `README.md` Status if a milestone moves, and refresh `memlog/DirectoryTree.txt` when structure changes (`AGENTS.md`).
