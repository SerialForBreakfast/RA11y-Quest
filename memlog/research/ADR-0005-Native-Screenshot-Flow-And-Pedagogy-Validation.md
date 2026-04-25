# ADR-0005: Reusable Swift Package for Screenshot, Flow, and Pedagogy Validation

Date: 2026-04-23
Status: Proposed

## Context

RA11y already has deterministic screenshot capture and a screenshot contract:

- screenshot scenes in `iOSScreenshotScene.swift`
- screenshot UI tests in `RA11y_iOSScreenshots.swift`
- route catalog in `ScreenshotRouteCatalog.md`
- fastlane extraction and validation scripts

That gets us reliable PNGs and alignment between test methods, scene IDs, and
expected filenames. It does not yet give us a strong native system for answering:

- Is the screen visually correct?
- Is the app in the intended semantic state?
- Is text clipped, truncated, or off-screen?
- Is a wrong asset being used, or is the right asset imported badly?
- Are sprites misaligned, oversized, or rendered with checkerboard / white matte /
  black matte issues?
- Does the captured screen resemble the approved mockup strongly enough?
- Do screenshots across a folder tell a coherent user flow?
- Does the instructional copy across those screens form a sensible learning arc?

We want a native macOS solution that can run locally and in CI/CD, stay mostly
deterministic, and scale beyond "file exists" checks into real UI iteration and
regression spotting.

We also want this capability to become a reusable, drag-and-drop Swift Package,
not a RA11y-only utility script. RA11y should be the first consumer and proving
ground, but the package should be broad enough to adopt in other app projects
without inheriting RA11y game concepts, file paths, screenshot scene names, or
fastlane lane structure.

The immediate implementation should be a local SPM package in this repository
and workspace. The long-term goal is to move the package into its own repository
or publishable package once the API, contract schema, command-line interface, and
CI integration surface have proven stable.

We also want to be realistic about platform capabilities.

### What is currently practical on macOS with native frameworks

Using Swift on macOS, we can reliably build:

- image metadata inspection with `ImageIO`, `CoreGraphics`, `CoreImage`
- OCR and text region extraction with `Vision`
- region and saliency analysis with `Vision`
- pixel / histogram / alpha / transparency analysis
- geometric heuristics (alignment, margins, edge clipping, safe-area proximity)
- perceptual or thresholded image comparison to baselines or mockups
- folder-level manifest generation and graph-style flow reports
- structured text analysis and summary generation with Foundation / Swift
- optional Foundation Models reasoning on top of structured evidence when available

### What is possible but should not be the primary CI gate

- semantic summarization from OCR + metadata + rule findings
- likely-cause inference ("wrong asset fallback", "state drift", "layout overflow")
- pedagogical quality summaries of prompt/copy sequences

These are useful, but should remain advisory unless they can be reduced to stable,
deterministic rules.

### What is currently weak, speculative, or not robust enough alone

- treating raw screenshot vision-language reasoning as the main source of truth
- trying to infer the exact intended product state from pixels alone with no contract
- trying to infer hidden accessibility semantics from screenshots alone
- relying on one giant "AI says it looks bad" pass/fail gate

## Decision

Create a separate local Swift Package that provides a reusable screenshot
validation engine, command-line tool, contract schema, rule system, and report
formats. RA11y will consume it as a local package from the workspace while the
API stabilizes.

Working package name for planning: `ScreenAuditKit`. The final name can change
before extraction, but the responsibilities should remain package-oriented.

Adopt a layered, native validation architecture built in Swift for macOS that
combines:

1. deterministic screenshot extraction
2. screen-specific validation contracts
3. asset integrity checks
4. baseline / reference comparison
5. navigation-flow modeling
6. pedagogy and copy-flow analysis
7. optional Foundation reasoning over structured evidence

This architecture should produce:

- hard failures for deterministic contract violations
- warnings for probable visual or design regressions
- flow reports that show how states progress across a run
- pedagogy reports that describe how instructions build from screen to screen

The core CI pass/fail path must remain deterministic. Foundation-backed reasoning
may summarize and prioritize findings, but must not be the sole decision-maker.

The package must not require fastlane. Fastlane is one integration target. The
primary integration boundary should be a stable CLI with explicit input paths,
config paths, report paths, and exit codes so GitHub Actions, Xcode Cloud,
Bitrise, Buildkite, CircleCI, Jenkins, local shell scripts, and future RA11y
pipelines can call the same executable.

RA11y-specific behavior should live in RA11y-owned contracts, profiles, and
optional adapter scripts, not in generic package code.

## Package Requirements

### Product requirements

- Provide a reusable SPM package that can be added to any Apple-platform project
  by local path during development and by package URL later.
- Include at least one library product for embedding validation logic in custom
  tools.
- Include at least one executable product for CI/CD and local command-line use.
- Run on macOS because screenshot analysis depends on Apple native frameworks
  such as Vision, CoreGraphics, ImageIO, CoreImage, and optionally AppKit.
- Accept screenshots from any capture system, including fastlane, XCTest
  attachments, `xcodebuild` xcresult extraction, Xcode Cloud artifacts, manually
  exported PNG folders, or another project's custom pipeline.
- Treat input contracts and screenshot folders as data, not as hardcoded app
  conventions.
- Emit deterministic machine-readable reports that downstream systems can parse.
- Emit human-readable summaries that are useful in PR review and design QA.
- Preserve a clear separation between hard CI blockers and advisory warnings.
- Support optional local reasoning summaries only after deterministic evidence is
  produced.

### Non-goals

- Do not become a screenshot capture framework in the first phase.
- Do not own simulator discovery, device booting, app launching, or fastlane lane
  orchestration.
- Do not depend on RA11y source files, route catalogs, or naming conventions.
- Do not require a cloud service, external model API, CocoaPods, Carthage, Ruby
  gem, Python runtime, Node runtime, or network access for core validation.
- Do not infer hidden accessibility semantics from screenshots alone.
- Do not make subjective design taste a hard CI gate.

### Package shape

Recommended local structure:

```text
ScreenAuditKit/
|-- Package.swift
|-- Sources/
|   |-- ScreenAuditKit/
|   |   |-- Contracts/
|   |   |-- Evidence/
|   |   |-- Rules/
|   |   |-- Reports/
|   |   |-- Baselines/
|   |   `-- Reasoning/
|   `-- screenaudit/
|       `-- main.swift
|-- Tests/
|   |-- ScreenAuditKitTests/
|   `-- ScreenAuditCLITests/
`-- README.md
```

Initial products:

- `ScreenAuditKit` library: contract decoding, screenshot evidence extraction,
  rule evaluation, report models, and stable public API.
- `screenaudit` executable: CLI wrapper suitable for fastlane and CI/CD.

Possible later products:

- `ScreenAuditFoundationReasoning` library or feature-gated module for optional
  Foundation Models summaries when the deployment target and host support it.
- `ScreenAuditTestSupport` helpers for package consumers that want fixture-based
  tests around their contracts.

### CLI requirements

The executable should support subcommands or equivalent modes:

- `inspect`: extract evidence from screenshots and write evidence JSON.
- `validate`: evaluate contracts and rules, write findings, and exit non-zero on
  hard failures.
- `flow`: analyze ordered screenshots and write navigation-flow findings.
- `pedagogy`: analyze ordered copy/lesson progression from OCR and contracts.
- `report`: convert evidence and findings into Markdown, JSON, JUnit, SARIF, or
  overlay artifacts.

The CLI should accept explicit paths:

- screenshot input directory
- contract file or contract directory
- optional baseline directory
- optional mockup/reference directory
- output directory for reports
- run metadata file, when available
- severity threshold for exit status

The CLI should not assume current working directory layout. It may provide
RA11y examples, but the generic interface must work from any project.

### Exit-code requirements

- `0`: no hard failures at or above the configured threshold.
- `1`: validation completed and found hard failures.
- `2`: usage/configuration error.
- `3`: input decoding or file access error.
- `4`: analyzer runtime error.

Exact numeric values can change before implementation, but they must be stable
once adopted by CI.

### Report requirements

Required report formats:

- JSON evidence report.
- JSON findings report.
- Markdown summary.

Strongly recommended formats:

- JUnit XML for generic CI test report surfaces.
- SARIF for GitHub code scanning or compatible review surfaces.
- Annotated PNG overlays for OCR boxes, protected regions, and visual diffs.
- Mermaid flow graph embedded in Markdown for ordered screenshot runs.

All reports must include enough source context to trace a finding back to:

- screenshot path
- scene or screen ID
- device label or dimensions
- contract rule ID
- evidence snippet or measured value
- severity
- confidence, when heuristic

### Contract schema requirements

The package should define a generic contract schema. RA11y can maintain its own
contracts using this schema.

The schema should support:

- project-independent screen IDs
- screenshot filename patterns
- device families, dimensions, orientation, and scale expectations
- ordered flow membership
- required OCR strings
- optional OCR strings
- forbidden OCR strings
- expected visual anchor regions
- critical text regions
- protected baseline comparison regions
- ignored volatile regions
- required source assets, when applicable
- asset transparency/matte expectations
- expected CTA or control labels
- screen role, such as entry, tutorial, play, success, failure, result
- pedagogy role, such as introduce, reinforce, practice, test, conclude
- rule severity overrides
- threshold overrides
- allowed variance per device family

Preferred storage format:

- JSON first, because it is portable, CI-friendly, and decodable by Swift
  without extra dependencies.
- Plist can be supported later if Apple-project ergonomics justify it.

Schema versioning is required from the beginning. Contracts should include a
schema version so future package versions can provide migration errors or
compatibility warnings.

### Rule-pack requirements

Rules should be composable and grouped into rule packs:

- core screenshot structure
- OCR text anchors
- clipping/truncation risk
- baseline comparison
- mockup/reference comparison
- asset integrity
- flow order
- pedagogy/copy progression

The generic package should ship broadly useful rule packs. RA11y-specific
profiles should select and configure those rule packs rather than forking the
engine.

### API design requirements

- Keep public API small until the local package has real consumers.
- Keep RA11y adoption through the CLI at first unless embedding the library gives
  immediate value.
- Make core data models `Codable`, `Sendable` where valid, and stable enough for
  report compatibility.
- Prefer deterministic pure functions for rule evaluation so they are easy to
  test.
- Isolate platform-specific Vision and image decoding code behind protocols or
  narrow services.
- Avoid global mutable state.
- Avoid hardcoded package-relative assumptions except for bundled test fixtures.
- Document all public and internal API with QuickHelp comments, following repo
  rules while the package lives here.

### Dependency requirements

- Use SwiftPM only.
- Start with Apple system frameworks and Swift standard library.
- Do not add third-party dependencies in the initial package unless a specific,
  actively maintained SPM dependency solves a non-trivial problem better than
  native frameworks.
- If a dependency is later accepted, pin an exact compatible version tag and keep
  it out of the deterministic CI path unless justified.

### Privacy and portability requirements

- Core validation must run offline.
- Raw screenshots must not leave the machine.
- Optional reasoning summaries must be local-only unless a future consuming
  project explicitly opts into a remote provider outside the core package.
- Reports should avoid embedding full raw OCR transcripts by default when a
  project marks screenshots as sensitive.
- The tool should be usable by non-RA11y projects with different app domains,
  screenshots, routes, and localization strategies.

### RA11y first-adopter requirements

RA11y integration should prove the generic design without compromising current
requirements:

- Local package is added to `RA11y.xcworkspace`.
- RA11y fastlane lanes call the package CLI after screenshot extraction.
- Existing screenshot contract validation remains in place until the package can
  cover equivalent checks.
- RA11y contracts live in a RA11y-owned directory, not inside generic package
  source.
- RA11y can define domain-specific roles for quest pedagogy while mapping them
  onto generic screen and pedagogy roles.
- RA11y asset checks for alpha, matte, checkerboard, and sizing become either a
  reusable asset rule pack or a RA11y profile layered on the package.
- The package must support the current RA11y flow requirement: ordered
  screenshots should validate both individual screen state and the lesson arc
  across a quest.

### Future extraction requirements

Before moving to a standalone SPM repository:

- Public API and CLI flags have been used by RA11y in more than one validation
  flow.
- Contract schema has at least one migration/versioning story.
- The package has fixture-based tests for OCR-free deterministic rules.
- CI output formats are stable enough for fastlane and at least one non-fastlane
  CI runner.
- README includes a minimal integration guide for a new project.
- RA11y-specific examples are clearly labeled as examples, not required
  conventions.
- Licensing, package naming, and repository ownership are decided.

## Scope

### In scope

- designing a local SPM package that can later be extracted or published
- defining package products, CLI behavior, report formats, and contract schema
- analyzing a folder of screenshots and related metadata
- validating expected visual anchors and text anchors
- detecting obvious clipping/truncation risks
- detecting non-transparent sprite failures such as checkerboards, white mats,
  black mats, or broken alpha
- detecting basic misalignment and oversizing regressions
- comparing screenshots against baselines and approved mockups
- producing a navigation-flow summary from the ordered screenshot set
- producing a pedagogy/copy-flow summary from OCR and scene contracts

### Out of scope

- replacing screenshot capture, simulator management, or app launch automation
- replacing UI tests with screenshot analysis
- replacing accessibility tree validation with screenshot-only inference
- relying on speculative multimodal model APIs as the only validation method
- making subjective visual design taste the primary CI blocker

## Proposed Architecture

### 1. Capture Layer

Existing screenshot capture remains authoritative.

Inputs:

- PNG screenshots
- scene IDs
- device labels
- xcresult metadata
- route catalog metadata

Outputs:

- per-image metadata
- ordered manifest for a run

### 2. Contract Layer

Introduce explicit validation contracts for each screenshotable scene.

A contract should define:

- scene ID
- screenshot filename
- device family expectations
- required OCR strings
- optional OCR strings
- forbidden OCR strings
- expected visual anchor regions
- expected CTA presence
- expected score/timer/state labels
- known allowed variance
- baseline reference image path
- reference mockup path, when available
- flow role (entry, tutorial, play, success, result)
- pedagogy role (introduce, reinforce, test, conclude)

Recommended format:

- JSON or plist checked into the repo
- decoded by Swift tools

Reason:

- machine-readable
- stable in CI
- easier to diff than embedding all rules in code comments

### 3. Perception Layer

Use native frameworks to extract structured evidence from each screenshot.

Recommended frameworks:

- `Foundation`
- `ImageIO`
- `CoreGraphics`
- `CoreImage`
- `Vision`
- `AppKit` only where necessary on macOS

Evidence to extract per screenshot:

- pixel size, color space, alpha presence
- OCR transcript
- OCR bounding boxes
- text block grouping
- estimated large empty regions
- safe-area edge occupancy
- saliency / dominant object regions
- histogram and brightness/contrast summary
- transparency defect signals
- baseline diff metrics
- mockup diff metrics

### 4. Rule Evaluation Layer

Convert structured evidence into deterministic findings.

Hard-fail examples:

- required title text missing
- required CTA missing
- screenshot dimensions wrong for expected device
- expected scene-specific anchor absent
- asset contract says transparent sprite but rendered output shows large flat matte
- baseline diff exceeds approved threshold in critical regions
- screenshot order missing a required state

Warn-level examples:

- possible text clipping near screen edge
- possible truncation from OCR bounding box compression
- alignment drift between repeated states
- contrast risk in critical text region
- mockup similarity below threshold but not catastrophic
- unexpected extra text in a supposedly clean deterministic screen

### 5. Asset Integrity Layer

This layer should validate source asset files and rendered screenshot symptoms.

Source asset checks:

- PNG alpha presence where transparency is required
- suspicious opaque borders
- suspicious checkerboard-like repeating background values
- white/black matte detection touching the image border
- imageset completeness and filename correctness

Rendered screenshot checks:

- visible checkerboard or matte blocks around a sprite
- fallback SF Symbol where custom art should appear
- incorrect mask edges or rectangular alpha plates
- assets obviously exceeding their intended frame

This can build on the Crystal Resonance asset QA direction and generalize it.

### 6. Baseline and Mockup Comparison Layer

Two comparison modes are needed.

#### Baseline comparison

Purpose:

- detect regressions from prior approved screenshots

Good for:

- layout drift
- missing controls
- spacing changes
- accidental design regressions

Risks:

- intentional design updates produce noise

Mitigation:

- region-specific thresholds
- approved baseline refresh workflow

#### Mockup comparison

Purpose:

- check whether implementation still resembles the intended design direction

Good for:

- large composition drift
- wrong hierarchy emphasis
- missing major visual groupings

Risks:

- mockups are aspirational and not pixel-identical

Mitigation:

- use as warn-level signal, not hard gate
- compare broad regions and major anchors, not raw per-pixel equality

### 7. Navigation Flow Layer

We need more than isolated screenshots. We need to reason about user progression.

Proposed output:

- per-run ordered manifest
- state transition chain
- optional Mermaid graph
- screen-to-screen diff summary

Example flow metadata per screenshot:

- scene ID
- route name
- prior scene
- next scene
- flow category
- expected transition reason

Flow checks:

- missing expected step
- duplicate state where progress should occur
- success screen without visible state change from prior play screen
- onboarding/tutorial screen not leading to first playable screen
- result screen missing contextual tie-back to the completed challenge

### 8. Pedagogy and Copy-Flow Layer

We should analyze not only the UI state, but the instructional sequence.

Inputs:

- OCR transcript from ordered screenshots
- scene contract pedagogy roles
- optional copy metadata from localization keys or scene descriptors

Questions this layer should answer:

- Does the first screen introduce the skill clearly?
- Does the next screen reinforce rather than repeat verbatim?
- Does trial copy remove hints at the right point?
- Does success copy confirm the learned action?
- Does the sequence actually teach one skill, or does it drift?

Deterministic checks:

- required lesson phrase appears in introduction
- later trial screens omit forbidden tutorial wording
- result screen includes skill-relevant success language
- no contradictory gesture wording across the flow

Foundation-assisted summary:

- describe whether the progression appears coherent, repetitive, abrupt, or muddled
- suggest where copy over-explains or under-explains

## Detectable Defects: What Is Actually Feasible

### Feasible now, reasonably reliable

- missing required text
- wrong device size / wrong orientation
- absent CTA text or title text
- OCR text near edges suggesting clipping risk
- source PNGs missing alpha
- rendered checkerboard / matte blocks around sprites
- obvious baseline regressions
- large alignment drift of centered assets
- missing or duplicated flow steps
- repeated tutorial copy where trial copy should appear

### Feasible with heuristics, useful as warning not hard fail

- clipped text
- truncated text
- insufficient padding around major art
- misalignment of major visual anchors
- low contrast in important regions
- implementation drift from mockup
- stale data shown in deterministic screenshots
- likely wrong asset fallback

### Difficult or speculative

- proving accessibility semantics from pixels alone
- understanding subtle animation quality from static screenshots
- proving VoiceOver focus order from screenshots alone
- judging overall design quality objectively
- guaranteeing pedagogy quality without scene metadata/contracts

## CI/CD Integration Strategy

Fastlane remains RA11y's current screenshot orchestrator, but the package should
not be designed around fastlane. The package boundary is the CLI and report
artifacts; any CI runner should be able to invoke the same executable after it
has produced screenshots.

### Fastlane integration

Proposed lanes:

- `screenshots`
  - capture only

- `screenshots_validate`
  - capture
  - validate screenshot contract
  - run native analyzer
  - fail on hard findings

- `screenshots_review`
  - capture
  - validate
  - generate overlays, Markdown report, JSON report
  - optionally run Foundation reasoning summary

- `screenshots_flow`
  - analyze a full ordered run or selected folder
  - emit navigation-flow and pedagogy summaries

Outputs:

- JSON evidence file
- JSON findings file
- Markdown summary
- optional annotated PNG overlays
- optional flow diagram Markdown

Fastlane should treat the package as an external executable:

```ruby
sh("swift run --package-path ../ScreenAuditKit screenaudit validate " \
   "--screenshots '#{OUTPUT_BASE}' " \
   "--contracts '../RA11y-iOS/RA11y-iOSUITests/ScreenshotContracts' " \
   "--output '../build_results/screen-audit'")
```

That command is illustrative only. The actual command should be refined during
implementation, and RA11y should use repo-local output paths.

### Other CI/CD integrations

GitHub Actions:

- Build or cache the SPM package.
- Run screenshot capture with the existing project pipeline.
- Run `screenaudit validate`.
- Upload JSON, Markdown, overlays, and JUnit/SARIF reports as artifacts.
- Optionally publish SARIF for code scanning annotations.

Xcode Cloud:

- Run as a post-test or post-build script after screenshot artifacts are
  available.
- Keep invocation path-based and avoid assumptions about fastlane.
- Store reports in Xcode Cloud artifacts.

Bitrise / Buildkite / CircleCI / Jenkins:

- Run the package executable from a shell step.
- Use exit code as the pass/fail signal.
- Publish JUnit XML and Markdown as build artifacts.

Local development:

- Run against an existing screenshot folder without requiring a simulator.
- Support a quick single-folder validation mode.
- Support a report-only mode that reuses prior evidence/findings output.

## Suggested Package Tooling

One possible package split:

### `ScreenAuditKit`

Responsibilities:

- decode contracts
- load screenshot folders and optional run manifests
- run OCR and image evidence extraction
- load evidence JSON
- evaluate hard/warn rules
- order screenshot runs
- validate flow coverage
- compare state-to-state deltas
- inspect OCR/copy sequence
- compare against pedagogy checklist
- build report models

### `screenaudit`

Responsibilities:

- parse CLI flags
- call `ScreenAuditKit`
- write JSON, Markdown, JUnit, SARIF, and overlay outputs
- map findings and runtime failures to stable exit codes

Subcommands are preferable to separate executables because one executable is
easier to wire into fastlane, Xcode Cloud, and generic CI shells.

## Validation Contracts and Checklists

To make this system useful, we need explicit checklists.

### Screen State Checklist

For each scene:

- title present
- primary instruction present
- primary CTA present if expected
- timer present if expected
- result rank visible if expected
- no forbidden tutorial wording in trial/result screens
- critical art anchor visible if expected
- no obvious clipping in required text regions
- no asset matte/checkerboard defect in critical art regions

### Flow Checklist

For a complete run:

- prologue/tutorial screen exists
- first playable screen exists
- progression state changes are visible
- success/result screen follows playable screen
- no missing transition
- no duplicate "stuck" state

### Pedagogy Checklist

For a skill arc:

- lesson is introduced once clearly
- gesture wording is consistent
- practice screen names the skill
- trial screen removes some scaffolding
- result screen reinforces what was learned
- no contradictory or redundant prompts

## Decision Boundary: Deterministic vs Reasoning

Hard CI blockers must come from deterministic rules.

Examples:

- missing required text
- wrong orientation
- missing anchor
- invalid asset alpha
- baseline diff above accepted threshold in protected region

Foundation Models or other reasoning should be used for:

- grouping related low-level issues
- summarizing flow quality
- summarizing pedagogy progression
- proposing likely causes or next steps

Reasoning output should not replace the raw findings.

## Consequences

Positive:

- Gives RA11y a native, privacy-preserving screenshot intelligence pipeline
- Produces a reusable package that can eventually serve other Apple projects
- Keeps fastlane integration thin by pushing validation semantics into the CLI
- Improves UI iteration speed by surfacing concrete defects automatically
- Expands from isolated screen checking into flow and pedagogy validation
- Keeps CI reliable by separating deterministic gates from optional reasoning
- Reuses Apple's native frameworks instead of depending on external cloud tools

Costs:

- Adds package API, schema, and CLI compatibility concerns earlier than a
  RA11y-only script would
- Requires explicit contract authoring for scenes and flows
- OCR and heuristic checks will need tuning to avoid noisy warnings
- Mockup comparison will need tolerant thresholds
- Flow and pedagogy analysis are only as good as the metadata we provide
- Static screenshot analysis will never replace all device-level QA

## Risks

- Too many warnings create alert fatigue
- Teams may over-trust heuristic findings
- Contract drift between product intent and implementation
- Generic package design may slow early RA11y-specific progress if the first
  milestone is scoped too broadly
- RA11y-specific concepts may leak into the package if contracts and adapters
  are not kept separate
- Foundation-assisted summary may sound confident even when evidence is thin
- Designers may expect aesthetic judgment from a system designed mainly for structural QA

## Mitigations

- keep pass/fail rules narrow and deterministic
- mark warnings with confidence and evidence
- require explicit contract ownership per screen
- keep the first implementation small: generic engine, RA11y contracts, CLI,
  and one fastlane call site
- reject package code that imports or hardcodes RA11y app paths, scene names, or
  quest terminology
- keep flow/pedagogy checks auditable and source-backed
- publish overlays and raw evidence alongside summaries

## Recommended Phase Plan

### Phase 0: Package skeleton and schema

- create local SPM package in the workspace
- define minimal `ScreenAuditKit` library and `screenaudit` executable products
- define versioned JSON contract and findings schemas
- add fixture-based tests for schema decoding and rule evaluation
- document a local package invocation that does not require fastlane

### Phase 1: Strong deterministic screenshot analysis

- OCR
- required/forbidden string checks
- dimension/orientation checks
- baseline diff
- asset alpha/matte checks
- Markdown + JSON reporting
- stable CLI exit codes
- RA11y fastlane integration after screenshot extraction

### Phase 2: Screen-state contracts

- per-scene machine-readable contracts
- critical region definitions
- mockup references
- RA11y contracts for the existing screenshot route catalog

### Phase 3: Flow analysis

- ordered manifests
- navigation-flow summaries
- screen-to-screen state delta reporting
- JUnit or SARIF output for CI visibility

### Phase 4: Pedagogy analysis

- prompt/lesson flow checklist
- OCR-driven copy sequencing
- result reinforcement checks
- RA11y quest pedagogy profile built on generic roles

### Phase 5: Optional Foundation reasoning

- summarize findings
- cluster probable root causes
- summarize flow and pedagogy quality

### Phase 6: Extraction readiness

- remove or isolate RA11y-only assumptions
- stabilize package name, README, license, and examples
- validate at least one non-fastlane invocation path
- decide whether the package remains local, moves to a sibling repository, or is
  published as a remote SPM dependency

## Acceptance Criteria

- ADR defines the tool as a reusable local SPM package, not a RA11y-only script
- Package requirements cover library product, CLI product, schema, reports, and
  CI exit behavior
- ADR clearly separates deterministic validation from optional reasoning
- Native Swift/macOS tooling is the primary proposed path
- Fastlane is supported without becoming a hard package dependency
- Other CI/CD environments are considered through CLI and report contracts
- Asset defect detection includes checkerboards, matte backgrounds, and alpha misuse
- Flow and pedagogy validation are explicitly included, not treated as afterthoughts
- The design is plausible for local and CI execution on macOS without requiring cloud AI
- RA11y-specific contracts and adapters are explicitly kept outside generic
  package source
