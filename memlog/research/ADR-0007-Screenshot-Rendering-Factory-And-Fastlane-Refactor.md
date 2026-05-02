# ADR-0007: Screenshot Rendering Factory and Fastlane Refactor

Date: 2026-05-01
Status: Proposed

## Context

RA11y currently captures committed screenshots through fastlane, `xcodebuild
test-without-building`, UI test methods in `RA11y_iOSScreenshots.swift`, and a
deterministic app launch argument:

```text
-uiTesting -screenshotScene <sceneID>
```

The app entry point detects the scene ID and renders `iOSScreenshotRootView`
instead of the normal startup router. That means the current flow already avoids
most real user navigation, onboarding timing, quest progression, persistence
state, and timer setup. The screenshot route catalog, `iOSScreenshotScene`,
Fastfile allowlist, and ScreenAuditKit contracts then validate that expected
screens exist and that captured PNGs satisfy deterministic visual contracts.

The remaining pain is capture time and maintenance friction:

- Each scene still launches the full iOS app process.
- XCUITest screenshots are stored as xcresult attachments and extracted later.
- Fastlane still coordinates simulator resolution, build-for-testing,
  test-without-building, attachment extraction, docs copy, and ScreenAuditKit.
- Screenshot-specific state is spread across `iOSScreenshotRootView`,
  per-quest `screenshotScene` initializers, result sample data, route catalog
  rows, UI test methods, and Fastfile allowlists.

The proposed idea is to refactor screenshot rendering around a factory/builder
that can generate each screenshot view with the right view model state, ideally
without launching the full application for every capture.

## Decision

Adopt a screenshot scene factory as an internal design direction, but do not
replace the fastlane/XCUITest screenshot lane with a pure in-process SwiftUI
renderer as the primary committed screenshot pipeline yet.

Use a two-track model:

1. **Primary release-quality capture remains simulator-backed.**
   Keep fastlane, `xcodebuild test-without-building`, real iOS rendering,
   root accessibility anchors, xcresult attachment extraction, docs copy, and
   ScreenAuditKit validation as the authoritative pipeline.

2. **Introduce a reusable screenshot scene factory underneath the current path.**
   Move screenshot state construction into a single app-owned builder so
   `iOSScreenshotRootView`, tests, previews, and any future renderer use the
   same source of truth for scene IDs, filenames, anchors, view model state, and
   sample data.

3. **Spike faster capture as a secondary lane after the factory exists.**
   Evaluate either:
   - a single-launch screenshot host that advances through factory scenes inside
     the running app process, or
   - an in-process SwiftUI render target for design iteration artifacts only.

The factory is worth doing for consistency and maintainability. A pure renderer
is not currently worth making the primary replacement because it cannot satisfy
all current testing requirements with the same confidence.

## Feasibility

### Feasible now

- Create a `ScreenshotSceneDescriptor` model containing:
  - scene ID
  - committed PNG basename
  - root accessibility identifier
  - supported device classes, if needed
  - flow grouping/order metadata
  - a builder closure that returns the SwiftUI view for that state
- Replace the `switch` in `iOSScreenshotRootView` with a registry lookup.
- Move result sample data and quest screenshot state into descriptor builders.
- Generate or validate route catalog expectations from the descriptor registry.
- Reduce drift between `iOSScreenshotScene`, `ScreenshotRouteCatalog.md`,
  `RA11y_iOSScreenshots.swift`, and Fastfile expected files.
- Make ScreenAuditKit flow contracts easier to derive from the same descriptors.
- Add a fast local preview/debug surface that shows every screenshot scene.

### Feasible with a spike

- A single-launch screenshot host view:
  - launch once per device with `-screenshotRun all`
  - render scene 1 from the factory
  - UI test captures the PNG after the root anchor exists
  - UI test taps a hidden/test-only "next scene" control
  - repeat until all scenes are captured

This would keep real simulator rendering and XCUITest screenshots while removing
most per-scene app cold starts. It is the most promising performance refactor.

- A renderer command or test target using SwiftUI rendering APIs:
  - instantiate factory scenes directly
  - render views to PNG without UI navigation
  - write files directly to an output folder

This would be useful for design iteration, mockups, and quick visual inspection,
but should not replace simulator-backed committed screenshots until proven
equivalent for layout, safe areas, assets, text rendering, and accessibility
anchors.

### Not feasible as a full replacement without tradeoffs

A pure builder/renderer cannot fully replace the current testing requirements
because it would not naturally validate:

- app launch integration and launch-argument routing,
- XCTest-visible accessibility identifiers,
- real simulator safe areas, scale factors, status bar behavior, and trait
  collections,
- app bundle resource loading under the same conditions as release screenshots,
- dynamic behavior around VoiceOver-required flows,
- actual `XCUIScreen` capture output,
- fastlane extraction from xcresult attachments,
- the contract that App Store-style screenshots come from a real simulator.

Those are not theoretical edge cases. RA11y has already used screenshots to catch
route drift, stale docs, missing files, asset problems, and wrong deterministic
states. A pure renderer could miss failures in the same integration surface.

## Limitations

### Factory limitations

- The factory can centralize state construction, but it does not itself make
  screenshot capture faster unless the capture path stops relaunching the app
  for each scene.
- Builders must avoid becoming a second app architecture. They should describe
  deterministic screenshot states, not own game logic.
- Complex quest views that currently mutate internal view model state for
  `screenshotScene` may need small seams to accept explicit state objects.
- If descriptors become too generic, they can obscure the pedagogical intent of
  each scene. Names and sample data must stay readable.

### Single-launch host limitations

- It still needs an iOS app process, simulator, XCUITest, and attachment
  extraction.
- Hidden/test-only controls must be compiled only for DEBUG or gated by
  `-uiTesting`.
- The host must wait for each scene to settle before capture.
- A crash or hang could interrupt the whole device pass, while the current
  per-scene relaunch path isolates failures better.
- Some scenes may require a clean environment. The host must ensure state does
  not leak between descriptors.

### Pure renderer limitations

- Rendering SwiftUI views outside the app can diverge from real-device layout.
- Accessibility identifiers and VoiceOver behavior are not validated the same
  way as XCUITest.
- Environment values must be reproduced manually: color scheme, Dynamic Type,
  locale, size class, safe area, layout direction, scale, and storage.
- Image and localization resource lookup can differ outside the iOS app bundle.
- It may encourage overfitting screenshots to renderer constraints instead of
  validating the product.

## Scope

### In scope

- Add an app-local screenshot scene descriptor/factory.
- Make `iOSScreenshotRootView` consume the factory.
- Keep `iOSScreenshotScene` or replace it with generated/static descriptors only
  if the route catalog validator remains strong.
- Move deterministic sample models into the factory or nearby fixtures.
- Add tests that every descriptor has a unique scene ID, filename, and root
  anchor.
- Update screenshot contract validation to check descriptor/catalog/test
  alignment.
- Spike a single-launch screenshot host after the factory is stable.
- Keep ScreenAuditKit as the post-capture validation layer.

### Out of scope

- Replacing fastlane entirely.
- Replacing ScreenAuditKit.
- Removing simulator-backed committed screenshot capture.
- Using a renderer-only flow as the App Store/docs screenshot source before it
  has proven fidelity.
- Building a generic screenshot renderer into ScreenAuditKit. ScreenAuditKit
  should remain capture-system agnostic.

## Level of Effort

### Phase 1: Scene factory cleanup

Estimate: 1-2 focused days.

Tasks:

- Define `iOSScreenshotSceneDescriptor`.
- Build a registry from all current scenes.
- Move filename and root anchor mapping into descriptors.
- Refactor `iOSScreenshotRootView` to use descriptor builders.
- Preserve existing launch argument behavior.
- Add descriptor uniqueness tests.
- Run `utility/validate_screenshot_contract.sh`, screenshot quick lane, and
  ScreenAuditKit validation.

Risk: low to medium. This is mostly a consolidation of existing behavior.

### Phase 2: Contract generation/validation improvements

Estimate: 1-2 focused days.

Tasks:

- Make the screenshot contract validator read descriptor-derived facts or a
  generated manifest.
- Reduce duplicate hardcoded scene metadata across UI tests and docs.
- Keep `ScreenshotRouteCatalog.md` human-readable, but validate it against the
  registry.
- Optionally emit a machine-readable screenshot manifest for fastlane and
  ScreenAuditKit.

Risk: medium. The validator currently reads source/docs text; changing the
contract shape must not weaken drift detection.

### Phase 3: Single-launch screenshot host spike

Estimate: 2-4 focused days.

Tasks:

- Add a DEBUG-only screenshot host mode.
- Render a sequence of descriptors in one app process.
- Add a UI test that advances through descriptors and captures each PNG.
- Compare runtime and output against the current lane.
- Decide whether to adopt as `screenshots_quick`, primary `screenshots`, or
  abandon.

Risk: medium to high. This touches process state, UI test timing, and failure
isolation.

### Phase 4: Renderer-only spike

Estimate: 3-5 focused days.

Tasks:

- Prototype direct SwiftUI PNG rendering for a small scene set.
- Force target device sizes and environment values.
- Compare pixel output and ScreenAuditKit findings with simulator screenshots.
- Decide whether it is useful as a local design iteration tool.

Risk: high if treated as release capture; acceptable if treated as advisory.

## Best Practices

- Keep one source of truth for scene ID, filename, root anchor, and builder.
- Keep real app views in the factory. Do not create screenshot-only replicas.
- Keep screenshot fixtures boring and explicit. Sample result data should be
  named and colocated with the scene it supports.
- Preserve accessibility anchors as required contract fields.
- Gate screenshot-only controls and host surfaces behind DEBUG plus `-uiTesting`.
- Treat fast screenshots as optimization, not as a reason to weaken coverage.
- Keep ScreenAuditKit capture-system agnostic: it should validate PNG folders and
  contracts no matter how the PNGs were produced.
- Prefer the single-launch host before a pure renderer because it keeps the most
  important integration guarantees.
- If a renderer-only lane is added, label it clearly as design-preview output
  until it proves parity with simulator capture.

## Would This Be Worth Doing?

The factory refactor is worth doing. It reduces duplication, makes screenshots
easier to reason about, and gives future lanes a clean integration point.

Replacing fastlane/XCUITest with direct view rendering is not worth doing as the
primary path right now. It would be faster, but it would not prove the current
requirements well enough. The most valuable next optimization is a single-launch
host that still captures from the simulator while avoiding per-scene cold starts.

Expected value:

- Factory only: moderate maintainability gain, little speed gain.
- Factory plus single-launch host: meaningful speed gain with acceptable coverage
  if the spike validates output parity.
- Pure renderer: high speed gain, lower confidence; useful for design iteration,
  not as authoritative release evidence.

## Can It Achieve Current Testing Requirements?

### Current requirements it can support

- deterministic scene selection,
- stable root anchors,
- required PNG basenames,
- route catalog alignment,
- visual contract validation through ScreenAuditKit,
- ordered flow reporting,
- fastlane or CI orchestration,
- reduced screenshot state duplication.

### Current requirements it cannot fully replace

Pure view rendering cannot fully replace:

- app launch argument validation,
- simulator/device rendering fidelity,
- XCUITest accessibility tree checks,
- xcresult attachment extraction,
- end-to-end fastlane screenshot behavior.

Therefore, the recommended answer is:

```text
Yes, build the factory.
Maybe adopt a single-launch host after a spike.
No, do not replace the authoritative simulator-backed screenshot lane with a
pure renderer yet.
```

## Recommended Workstream

1. Add `iOSScreenshotSceneDescriptor` and registry.
2. Refactor `iOSScreenshotRootView` to build scenes from the registry.
3. Add descriptor tests for uniqueness and required metadata.
4. Update the screenshot contract validator to compare catalog rows against the
   registry or a generated manifest.
5. Run the existing screenshot quick lane and ScreenAuditKit to confirm parity.
6. Spike the single-launch host and measure runtime against the current lane.
7. Decide whether to promote the host to `screenshots_quick` first.
8. Consider a pure renderer only for local design-preview artifacts.

## Consequences

Positive:

- Screenshot state becomes easier to maintain.
- The route catalog can become less manually duplicated.
- Fastlane can stay focused on orchestration.
- ScreenAuditKit remains independent and reusable.
- Future CI/CD integrations can consume a manifest instead of scraping app code.

Negative:

- Adds another app-side abstraction.
- Requires discipline to avoid screenshot-only UI forks.
- A single-launch host may make failures less isolated.
- Renderer-only output may confuse reviewers if mixed with authoritative
  simulator captures.

## Follow-Up Questions

- What runtime reduction would justify replacing the current per-scene relaunch
  path?
- Should `screenshots_quick` become the experimental host lane while
  `screenshots` remains conservative?
- Should the screenshot descriptor registry emit a JSON manifest for fastlane and
  ScreenAuditKit?
- Which scenes require clean per-launch state and may not be safe in a
  single-process sequence?
