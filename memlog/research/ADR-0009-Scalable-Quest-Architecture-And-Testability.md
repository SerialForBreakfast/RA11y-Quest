# ADR-0009: Scalable Quest Architecture and Testability

Date: 2026-06-01
Status: Proposed

## Context

RA11y has evolved from a single iOS prototype into a multi-quest accessibility
training product. The current architecture already has several strong choices:

- `RA11yCore` owns shared catalog, scoring, storage, session lifecycle, VoiceOver
  gating, result presentation, feedback reduction, and hub view model logic.
- The iOS app owns SwiftUI presentation, UIKit accessibility integration,
  platform-specific feedback renderers, screenshots, and asset catalogs.
- `GameSession` is an actor-backed lifecycle state machine with injectable
  storage and deterministic date inputs.
- Completed quests have deterministic screenshot routes and fastlane coverage.

That shape is good for the current app, but future scale will stress it:

- Quest implementation files are now large: `iOSEnchantersTrialView.swift`,
  `iOSBanishmentQuestView.swift`, `iOSDungeonDescentView.swift`, and related
  Crystal Resonance views hold view code, quest progression, timers, copy
  selection, scoring decisions, accessibility announcements, screenshot state,
  and platform calls in one place.
- New features such as tvOS/macOS variants, deeper lesson sequences, richer
  accessibility curricula, analytics, release screenshot validation, and
  product experimentation will need the same quest rules without always needing
  the same SwiftUI views.
- Test value is uneven. `RA11yCore` tests verify durable behavior cheaply, while
  much quest-specific behavior currently requires iOS view/UI execution or is
  validated indirectly through screenshots.
- Routing and catalog knowledge is duplicated across `GameKind`,
  `GameCatalog`, `RankThresholds`, `iOSAppRouter`, result replay mapping, Basics
  sequence arrays, screenshot routes, and platform views.

The goal is not to introduce architecture for its own sake. The goal is to make
future quests cheaper to build, safer to change, more portable across Apple
platforms, and more provable through high-value tests.

## Decision

Adopt a staged architecture direction: **quest logic becomes portable engines in
core; platform apps become renderers and adapters; product/screenshot flows are
driven from validated manifests.**

This is a direction for new work and opportunistic refactors. Do not stop
feature delivery for a broad rewrite.

## Proposed Architecture

### 1. Keep `RA11yCore` as the shared product-domain module

`RA11yCore` should remain the home for platform-neutral product logic:

- quest catalog metadata,
- unlock rules,
- session lifecycle,
- scoring and rank thresholds,
- result presentation,
- storage contracts,
- feedback events and reductions,
- VoiceOver start-gating decisions,
- quest state machines that can run without SwiftUI/UIKit.

Core should not import SwiftUI, UIKit, AVFoundation, CoreHaptics, or platform
asset APIs.

### 2. Extract quest engines from large iOS views

For each substantial quest, introduce a platform-neutral engine in
`RA11yCore/Sources/RA11yCore/Quests/<QuestName>/`.

An engine should own:

- phase/progression state,
- accepted player actions,
- mistake conditions,
- timer policy as logical time inputs,
- scoring inputs,
- tutorial/trial mode rules,
- emitted semantic events such as `announcement`, `feedbackCue`, `completed`,
  and `mistakeRecorded`.

The iOS SwiftUI view model should become a thin adapter:

- translates gestures/accessibility actions into engine actions,
- renders engine state,
- posts announcements through an injected platform announcer,
- starts/stops platform timers,
- invokes `GameSession` or storage through core protocols,
- owns only iOS-only details such as focus, `UIAccessibility.post`, and
  `@AccessibilityFocusState`.

Do this first for the next quest or for the file that is actively changing. The
current strongest candidates are Enchanter, Banishment, and Crystal Resonance
because each has large view files and meaningful progression rules.

### 3. Introduce platform adapter protocols for high-value side effects

Add small protocols at the boundary where quest code currently reaches directly
for platform services:

- `AccessibilityAnnouncer`: posts screen changes, layout changes, and spoken
  announcements.
- `QuestClock`: provides deterministic ticking or logical time advancement.
- `FeedbackRendering`: renders semantic feedback events to haptics/audio.
- `QuestEnvironment`: exposes reduced motion, VoiceOver running state, and other
  platform environment facts as injected values.

Keep these protocols narrow. They are test seams, not a dependency-injection
framework.

### 4. Move quest catalog composition toward a manifest

Create a single validated quest manifest model that becomes the durable source
for:

- `GameKind`,
- `GameCatalog.all`,
- rank-threshold lookup,
- route/replay mapping,
- Basics sequence membership,
- screenshot scene grouping,
- quest availability and prerequisites,
- player-facing quest stage names.

This can start as typed Swift data, not JSON. The important change is that
routing and product metadata are declared once and tested for consistency.

Avoid a runtime plugin system for now. RA11y does not need dynamic quest loading;
it needs static compile-time safety with less duplicated wiring.

### 5. Use feature modules only when boundaries become real

Do not immediately split every quest into a separate Swift package. That would
increase project-management cost before the domain seams are clean.

Prefer this sequence:

1. Extract quest engines into folders inside `RA11yCore`.
2. Add focused tests against those engines.
3. Move shared iOS quest chrome/components out of individual quest files.
4. Only then consider additional SwiftPM targets such as:
   - `RA11yQuestEngines`
   - `RA11yDesignSystem`
   - `RA11yPlatformAdapters`

Use a new target only when it enforces a useful dependency rule. For example,
quest engines must not import SwiftUI; iOS renderers may import quest engines.

### 6. Separate screenshot state from gameplay state

Screenshot routes are now valuable release evidence. They should not require
view models to carry ad hoc `screenshotScene` branches indefinitely.

Follow ADR-0007 and introduce screenshot descriptors/factories that declare:

- scene ID,
- output filename,
- root accessibility anchor,
- product stage,
- builder state,
- flow order.

Quest engines should support deterministic state construction, but screenshot
metadata should live beside the screenshot factory rather than being scattered
through gameplay methods.

## Testability Strategy

Testability should optimize for product confidence, not raw coverage numbers.

### Most valuable tests

1. **Quest engine transition tests**
   - Given a phase and action, assert next phase, mistake count, emitted events,
     and completion conditions.
   - These are fast, deterministic, and protect the rules players experience.

2. **Timer and scoring tests with logical time**
   - Drive elapsed time explicitly instead of sleeping.
   - Assert rank boundaries and timeout behavior.
   - This catches high-impact fairness regressions.

3. **Accessibility contract tests**
   - Verify each quest stage exposes the required semantic intent:
     instruction, target action, mistake feedback, success feedback, and result.
   - Where possible, test core semantic events; use UI tests only for platform
     accessibility plumbing.

4. **Catalog/manifest consistency tests**
   - Every quest has a catalog row, route mapping, rank thresholds, result replay
     mapping, screenshot coverage state, and prerequisite relationship.
   - These tests prevent product drift.

5. **Golden-path integration tests**
   - A small number of UI tests should prove launch, navigation, VoiceOver gates,
     screenshot routes, and result persistence.
   - Avoid using UI tests for every engine branch.

6. **Screenshot tests**
   - Keep them as release evidence for completed flows.
   - Their value is visual/product validation, not exhaustive logic coverage.

### Lower-value tests

- Snapshotting every SwiftUI subview without a stated user risk.
- Testing private implementation details of view layout.
- Duplicating engine branch tests through slow UI automation.
- Increasing coverage with tests that only assert views can initialize.

## Consequences

### Positive

- New quests can reuse session, scoring, feedback, and lifecycle patterns without
  copying large view-model blocks.
- tvOS/macOS variants can render the same quest rules with different platform
  controls.
- Screenshot and product docs can be generated from the same durable metadata.
- Unit tests become more meaningful because they validate quest rules and
  accessibility pedagogy directly.
- Large iOS SwiftUI files shrink toward rendering and platform behavior.
- Future ADR product directions have a stable place to land: add a quest engine,
  register it in the manifest, render it on each platform.

### Costs

- Initial extraction adds some types and adapters.
- Poorly designed protocols could create indirection without value.
- Moving too much too quickly would slow feature work.
- Some accessibility behavior still requires real device/simulator validation;
  core tests cannot replace platform QA.

## Migration Plan

### Phase 1: Establish boundaries without moving targets

- Add a short architecture map to `memlog` identifying current ownership:
  core domain, iOS presentation, automation/docs.
- Add manifest consistency tests around existing `GameCatalog`, `GameKind`,
  `RankThresholds`, Basics sequence, and replay routing.
- Extract obvious shared mappings, such as game ID to `GameKind`, out of
  `iOSRootView` into core.

### Phase 2: Extract one quest engine

- Choose the next actively modified quest.
- Define a core state/action/event model.
- Move progression, mistake, timer, and completion rules into the engine.
- Keep the SwiftUI view visually unchanged.
- Add fast engine tests for every branch that previously required manual QA.

### Phase 3: Repeat only where pressure exists

- Apply the same pattern to other large quest files when touched for feature
  work.
- Extract shared iOS quest shell/chrome only after two or more quests need the
  same behavior.
- Keep one-off view code local until duplication is real.

### Phase 4: Reconsider module targets

- If core folders become too broad, split SwiftPM targets along dependency
  rules:
  - domain engines without SwiftUI,
  - design tokens/components,
  - platform adapters.
- Do not split solely for aesthetics.

## Decision Rules for Future ADRs

When evaluating a new product or architecture proposal, ask:

1. Does this feature add new product rules, or only new presentation?
2. Can the rule be tested without SwiftUI/UIKit?
3. Is the rule shared across iOS, tvOS, macOS, screenshots, or docs?
4. Does the change reduce duplicated catalog/routing/scoring knowledge?
5. Does it improve accessibility pedagogy validation?
6. Does it preserve deterministic screenshot/release evidence?
7. Is the proposed abstraction justified by at least two consumers or one high
   risk boundary?

If the answer is mostly “presentation only,” keep it in the platform app. If the
answer is “product rule,” move it toward core.

## Non-Goals

- Adopt a named architecture framework across the app.
- Rewrite all existing quests immediately.
- Add a runtime plugin system.
- Move SwiftUI views into `RA11yCore`.
- Replace simulator/UI validation with unit tests.
- Split into many SwiftPM targets before dependency boundaries are proven.

## Open Questions

- Should the quest manifest remain Swift-only, or eventually emit a JSON
  product manifest for docs and automation?
- Should Basics sequence membership be a property of catalog metadata or a
  separate curriculum manifest?
- How much of screenshot descriptor data should be generated from the quest
  manifest versus kept in screenshot-specific factories?
- Which platform should drive the first non-iOS renderer: tvOS remote-focus
  training or macOS keyboard/VoiceOver training?
