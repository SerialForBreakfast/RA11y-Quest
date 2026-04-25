# Design Recommendation Review

Date: 2026-04-24

## Goal

Create a consistent RA11y quest UI that scales cleanly across iPhone small, iPhone large, and iPad screenshots. The design system should make the hub, prologues, encounters, and result screens feel like one product while still allowing each quest to keep its own illustrated environment and mechanic.

## Screenshot Pass Summary

Reviewed the committed screenshot set in `fastlane/screenshots/en-US/` for iPhone small, iPhone large, and iPad, with special attention to:

- `01_Hub`
- `04_EnchanterPrologue`
- `08_EnchanterResult`
- `09_DungeonPrologue`
- `10_DungeonL1`
- `13_BanishmentPrologue`
- `14_BanishmentWardTrap`
- `16_BanishmentResult`

The iPad hub margin issue is real, but it is a symptom of a broader inconsistency: every quest surface is solving layout, chrome, teaching copy, and button placement slightly differently.

## Current Findings

### 1. iPad hub uses a narrow phone-like card lane

The iPad hub centers content, but the active card column is too narrow for the available canvas. The first quest card wraps "The Enchanter's Trial" into short stacked lines, while the background has large unused side areas. This makes the iPad screenshot feel accidental rather than intentionally adaptive.

Likely source: `iOSHubView` uses `QuestPaintContentMetrics.readingColumnMaxWidth` with a regular-width cap around 620 points, then each card uses the same narrow reading lane. That cap is appropriate for prose but not for quest cards that need image, title, description, status, and lock state.

### 2. Reading content, card content, and playfields need separate width rules

The current shared metric treats most surfaces as a reading column. That works for result prose and some lesson copy, but not for:

- Hub quest cards
- Encounter playfields
- Dungeon resonance lane chrome
- Result action buttons when the card stack is wider

The system needs separate layout roles, not one universal max width.

### 3. Prologue screens have matching intent but not matching structure

Enchanter, Crystal Resonance, and Banishment all teach a VoiceOver gesture, then start the quest. They do not share one prologue scaffold.

Examples:

- Enchanter uses DM narration, lesson card, shared spell plate, gesture rows, and "Begin Trial".
- Crystal Resonance uses narration, lesson card, gesture rows, shared spell plate, a practice scroll zone, and a disabled begin button.
- Banishment mostly centers the shared spell plate and "Continue to the Tower"; supporting title/body copy exists in code but is visually absent in the current iPad screenshot because the spell plate dominates the first viewport.

The user experience should be "learn the gesture, practice if required, start the encounter" every time, with the same layout grammar.

### 4. Result screens are closer to the desired system

The result screen already has the strongest reusable structure:

- Shared full-bleed quest backdrop
- Shared readable scrim
- Shared result summary
- Shared "What You Learned" card
- Shared gesture reminder card
- Shared action stack

This should become the model for the rest of the quest UI. The main improvement is to align result screen width rules and button styling with the proposed layout roles.

### 5. Terminology is inconsistent across quest states

Current terms mix "Trial", "Quest", "Tower", "Descent", "Gauntlet", "Tavern", "Result", "Begin", "Continue", and "Back to Tavern". Some of that is thematic, but the product-level hierarchy should be predictable.

Recommended product vocabulary:

- `Quest`: the whole activity selected from the hub.
- `Prologue`: the pre-play teaching screen.
- `Encounter`: an active playable challenge beat.
- `Result`: the post-quest summary.
- `Tavern`: the hub destination in user-facing action labels.
- `Begin Quest`: first action from prologue into play.
- `Continue`: intra-quest progression after a completed beat.
- `Try Again`: replay the same quest from the beginning or current failed beat, as specified by the flow.
- `Back to Tavern`: return to hub.

Quest-specific language can remain in flavor copy, but primary buttons and navigation should use the same product vocabulary.

### 6. The design token layer exists but needs stronger component boundaries

Existing reusable pieces are a good base:

- `RA11ySpacing`
- `RA11yRadius`
- `Color.ra11y*`
- `QuestPaintAmbientBackdrop`
- `QuestPaintReadableScrim`
- `QuestPaintReadableTextRole`
- `QuestPaintContentMetrics`
- `QuestStandardPrimaryButton`
- `QuestStandardSecondaryButton`
- `QuestGameResultActionStack`
- `QuestVoiceOverGestureSpellPlate`

The gap is not a lack of tokens. The gap is that screens still compose their own scaffolds, max widths, card surfaces, button placement, and prologue structure.

## Recommended Design System

### 1. Introduce layout roles

Replace the single "reading column" mental model with named layout roles:

| Role | Purpose | iPhone target | iPad target |
|---|---|---:|---:|
| `reading` | Narrative copy, instructions, result prose | full width minus 16-24 pt | 600-680 pt |
| `questCardList` | Hub quest cards | full width minus 16 pt | 760-900 pt |
| `lesson` | Prologue teaching stacks | full width minus 16-24 pt | 680-760 pt |
| `playfield` | Active encounter content | full width | 760-1000 pt or full bleed by mechanic |
| `actions` | Primary/secondary buttons | match parent content | match parent content, capped with parent |

Implementation direction:

- Add a `QuestLayoutRole` enum.
- Replace `QuestPaintContentMetrics.scrollHorizontalPadding(...)` with a role-aware API.
- Keep centered content on iPad, but avoid forcing card/playfield surfaces into prose-width columns.

### 2. Create shared quest screen chrome

Add a reusable quest scaffold for illustrated screens:

```swift
struct QuestPaintScreen<Content: View>: View {
    let backgroundImageName: String
    let layoutRole: QuestLayoutRole
    let content: () -> Content
}
```

Responsibilities:

- Full-bleed background art
- Shared readable scrim
- Dark color scheme
- Safe-area handling
- Role-based content width
- Standard vertical padding
- Optional top/bottom inset support

This should replace hand-rolled `ZStack`, `.background`, and `GeometryReader` usage on prologue/result screens where possible.

### 3. Create shared prologue components

Add a consistent prologue model and view:

```swift
struct QuestPrologueContent {
    let title: String
    let narration: String?
    let lessonHeading: String
    let lessonBody: String
    let gesturePlate: QuestVoiceOverGestureSpellPlate
    let practice: QuestPracticeRequirement?
    let primaryActionTitle: String
}
```

Reusable pieces:

- `QuestNarrationCard`
- `QuestLessonCard`
- `QuestGestureRows`
- `QuestPracticeCard`
- `QuestPrologueActionBar`

Expected result:

- Enchanter, Crystal Resonance, and Banishment all share the same order and spacing.
- Quest-specific flavor changes copy and art, not the overall screen grammar.
- Banishment can keep the large Z gesture art, but within the same prologue scaffold.

### 4. Standardize hub cards separately from reading cards

Hub cards should become a dedicated adaptive component:

- iPhone: compact vertical or media-leading card, full available width.
- iPad: wider media-leading card with image, title, description, status, and lock state arranged without awkward title wrapping.
- Locked cards should be readable without looking disabled to the point of illegibility.
- The card list should use the `questCardList` layout role, not the `reading` role.

Specific iPad recommendation:

- Increase hub card content width from the current prose cap to roughly 760-840 points.
- Consider a two-column iPad grid only if the lock/progression story remains obvious. A single wider column is safer for VoiceOver order and current screenshot continuity.

### 5. Standardize encounter HUD and action surfaces

Each active encounter should share:

- Objective card pattern
- Timer/mistake HUD pattern
- Feedback/status message pattern
- Continue/retry action placement
- VoiceOver hint phrasing

Quest-specific mechanics can remain custom:

- Enchanter relic list
- Crystal resonance lane
- Banishment trap overlay

But their surrounding chrome should use shared components so screenshots feel related.

### 6. Standardize result screen as the baseline

Keep `iOSGameResultView` as the reference implementation, then extract pieces that other screens should share:

- Summary card surface style
- Skill-transfer card surface style
- Gesture reminder treatment
- Primary/secondary action stack

Recommended tweaks:

- Use the same role-based layout metrics as prologues.
- Ensure result buttons align to the same content width as the cards.
- Keep "Back to Tavern" as the consistent hub-return label across all result screens.

## Terminology Recommendations

Use these strings consistently for primary UI:

| Context | Recommended label |
|---|---|
| Hub navigation title | `RA11y Quest` visually, `Rally Quest` for VoiceOver |
| Hub heading | `Choose Your Quest` or `Choose Your Trial` |
| Prologue primary action | `Begin Quest` |
| Practice-complete progression | `Continue` |
| Result replay | `Try Again` |
| Result exit | `Back to Tavern` |
| VoiceOver teaching heading | `How VoiceOver Works Here` |
| Skill transfer heading | `What You Learned` |
| Gesture reminder heading | `Gestures in This Quest` |

Open naming decision:

- The hub currently says "Choose Your Trial, Adventurer", while cards and results use quest language. Pick either `Quest` as the product term and `Trial` as flavor, or keep `Trial` everywhere. Recommendation: use `Quest` for product structure and let individual quest titles use "Trial", "Resonance", or "Banishment".

## Accessibility Requirements

VoiceOver is not an enhancement layer for RA11y. It is the primary interaction model and must be designed into every reusable component. The design system should preserve RA11y-specific accessibility behavior and make correct behavior repeatable across every quest.

### VoiceOver design principles

- Build for linear navigation first. A user should be able to understand and complete each screen by swiping through elements in order.
- Use semantic controls for actions. Prefer `Button`, `Toggle`, and other native controls over gesture-only views unless the quest mechanic specifically requires a VoiceOver gesture.
- Keep one clear objective per playable screen. The objective should be near the beginning of the VoiceOver order and should explain what to find, activate, scroll to, or escape from.
- Keep focusable elements intentional. Decorative art, backgrounds, particles, scrims, and purely visual icons should be hidden from accessibility.
- Group related lesson copy into one logical element when separate swipes would make the instruction harder to understand.
- Do not over-group active playfields. Interactive choices should remain individually reachable when the mechanic depends on choosing among items.
- Do not rely on color, position, animation, or visual proximity as the only source of meaning.
- Support Dynamic Type without clipping, hidden controls, or unreachable content.

### Component-level accessibility contract

Every reusable quest component should declare and preserve its accessibility contract:

- Interactive controls keep explicit accessibility labels and hints.
- Decorative background and creature art remains hidden from accessibility.
- Lesson cards combine related copy into one logical VoiceOver element where helpful.
- Gesture practice areas expose clear labels and hints.
- Dynamic Type must not clip cards or buttons at large sizes.
- Do not use color alone for lock, success, timer, or target state.
- Keep VoiceOver reading order consistent: title, lesson/objective, playfield, status, actions.
- Primary action buttons expose the action result in the hint, especially when the visible label is thematic.
- Status, timer, mistake, lock, and success states have spoken equivalents.
- Components with custom accessibility actions document those actions and keep them stable across quests.
- Components used by screenshot automation keep stable root accessibility identifiers.

### Recommended VoiceOver screen order

Use this order unless a quest mechanic gives a clear reason to vary it:

| Screen type | VoiceOver order |
|---|---|
| Hub | Navigation title, orientation guidance, hub heading, quest cards, VoiceOver Basics, VoiceOver enable/help affordance |
| Prologue | Navigation title, quest title, narration, lesson, gesture teaching card, practice area if required, primary action |
| Encounter | Navigation title, objective, timer/mistakes if present, status/hint, active playfield, continue/retry/escape action |
| Result | Navigation title, rank summary, quest-specific result copy, skill transfer, gesture reminder, Try Again, Back to Tavern |

### Quest-specific VoiceOver patterns to preserve

- Hub: keep the custom "Quests" rotor so users can jump between quest cards without traversing every surrounding element.
- Hub: when VoiceOver becomes enabled on the hub, move focus predictably to the first available quest card after the UI settles.
- VoiceOver gate: if VoiceOver is required for a quest, the interstitial should clearly explain why and how to proceed.
- Enchanter: item navigation should mirror the lesson: swipe right/left through relics, then double-tap the named target.
- Crystal Resonance: the scroll lane should remain a single reliable scroll surface for VoiceOver, with clear objective and alignment feedback rather than duplicate decorative lane elements.
- Banishment: the escape gesture must remain available through `accessibilityAction(.escape)` on the active trap surface and any combined instruction card that represents the trap.
- Results: every quest should restate the learned gesture in product language and give a real-world transfer example.

### Reliability rules for repeatable functionality

- Stable identifiers are part of the design system, not test-only implementation detail.
- A screenshot-covered screen must have one documented root anchor and one predictable primary focus path.
- If a visual component changes its layout role, re-check VoiceOver order, Dynamic Type, and screenshot coverage together.
- If a component introduces a custom accessibility action, add a short code doc comment explaining who uses it and when it fires.
- If a quest has a practice gate, the disabled/enabled state of the primary action must be visible and spoken.
- If a screen updates status during play, avoid noisy repeated announcements; announce only meaningful state changes.
- If VoiceOver is disabled mid-game, the route back to the VoiceOver-required interstitial must remain consistent.

### Accessibility validation checklist

Before accepting a redesigned quest screen:

- Swipe order matches the recommended order for that screen type.
- The user can identify the current quest, current objective, current state, and available action without seeing the screen.
- All visible actions are reachable with VoiceOver and have useful hints.
- Decorative art is skipped.
- Custom actions such as escape are available where the design says they are required.
- Dynamic Type does not clip instructional copy, buttons, or status text.
- The screenshot root identifier still matches `ScreenshotRouteCatalog.md`.
- The UI test route can wait on the documented root anchor before capture.
- The same component behaves consistently on iPhone small, iPhone large, and iPad.

## Implementation Plan

### Phase 1: Define design-system primitives

- Add `QuestLayoutRole` and role-aware width/padding metrics.
- Add `QuestPaintScreen` for full-bleed illustrated screens.
- Add shared card surfaces: `QuestNarrationCard`, `QuestLessonCard`, `QuestStatusCard`, and `QuestActionBar`.
- Add accessibility contracts to each shared component: grouping behavior, labels/hints responsibility, expected focus role, and identifier expectations.
- Add doc comments for every internal type and API per repo rules.

### Phase 2: Fix the iPad hub with the new metrics

- Move hub card list to `questCardList` role.
- Increase iPad card width and reduce awkward title wrapping.
- Keep a single centered list initially for stable VoiceOver order.
- Recheck locked-card contrast and disabled-state readability.

### Phase 3: Normalize prologue screens

- Refactor Enchanter prologue into shared scaffold first because it is the clearest current pattern.
- Refactor Crystal Resonance prologue next, preserving the required practice scroll gate.
- Refactor Banishment prologue last, keeping the authored Z gesture art but restoring a complete title/body/action hierarchy.
- Validate the prologue VoiceOver order after each refactor before moving to the next quest.

### Phase 4: Normalize encounter chrome

- Extract common objective, timer, mistake, status, retry, and continue components.
- Apply to Enchanter gameplay and Crystal Resonance HUD first.
- Apply compatible pieces to Banishment trap/tower without flattening its escape-gesture mechanic.
- Preserve quest-specific VoiceOver mechanics while making the surrounding objective/status/action chrome consistent.

### Phase 5: Align result screens and terms

- Confirm all result screens use the same card widths, action stack, and labels.
- Update `Localizable.xcstrings` so product terms are uniform.
- Keep quest-specific flavor in narration and result flavor text only.

### Phase 6: Screenshot validation

- Regenerate screenshots for iPhone small, iPhone large, and iPad.
- Compare all required scenes in `ScreenshotRouteCatalog.md`.
- Verify each screenshot route still has a documented root accessibility identifier and predictable initial focus path.
- Add or update ScreenAuditKit rules if needed for:
  - minimum side margin
  - maximum readable column width
  - no obvious button/text clipping
  - no unintended narrow iPad hub card lane

## Acceptance Criteria

- iPad hub cards no longer wrap major titles into narrow stacked fragments.
- Prologue screens share the same content order, spacing rhythm, and action placement.
- Encounter screens share objective/HUD/status/action chrome while keeping unique mechanics.
- Result screens match the prologue and encounter visual language.
- Product terms are consistent across hub, prologue, encounter, and result states.
- VoiceOver order and interaction behavior are consistent across hub, prologue, encounter, and result states.
- Every reusable quest component has a documented accessibility contract.
- Quest-specific VO mechanics remain intact: hub rotor/focus, Enchanter swipe-and-activate, Crystal scroll surface, Banishment escape action, and result skill transfer.
- All screenshot-covered scenes pass on iPhone small, iPhone large, and iPad.
- The reusable components reduce one-off layout code in quest screens rather than adding another parallel style.

## Recommended First Task

Start with `QuestLayoutRole` plus the iPad hub width fix. That directly addresses the visible screenshot problem while creating the foundation needed for the prologue/result unification work.

## Related engineering artifacts

- **Code ↔ review mapping:** [`memlog/DesignRecommendationCodeMap.md`](DesignRecommendationCodeMap.md) (screenshot routes, metrics call sites, prologue/result file pointers).
- **Checklist / Phase 1 tickets:** [`memlog/designRefactorTasks.md`](designRefactorTasks.md) — section *Quest UI System Refactor* (UI-1 … UI-11) and **Phase 1 execution tickets** under Task UI-1.
