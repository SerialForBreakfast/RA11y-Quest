# ScreenAuditKit Workstream

Date: 2026-04-24
Status: Draft
Source ADR: `memlog/research/ADR-0005-Native-Screenshot-Flow-And-Pedagogy-Validation.md`

## Purpose

Create `ScreenAuditKit` as a reusable local Swift Package that validates screenshot
state, visual structure, flow order, and instructional copy. RA11y is the first
consumer, but the package must remain portable enough to drag into other Apple
projects later as a normal SPM dependency.

The workstream is intentionally split into package-generic tasks and RA11y adapter
tasks. Generic package code owns contracts, evidence, rules, reports, and CLI
behavior. RA11y owns screenshot capture, app-specific contracts, quest pedagogy
profiles, fastlane invocation, and any migration from existing validation scripts.

## Operating Principles

- Build the smallest useful package first.
- Keep fastlane as an adapter, not a dependency.
- Keep screenshot capture outside the package for the first implementation.
- Keep RA11y paths, scene IDs, quest names, and route catalog parsing outside
  generic package source unless represented as data contracts.
- Make deterministic validation the CI gate.
- Treat OCR, image heuristics, flow analysis, and pedagogy analysis as evidence
  pipelines whose outputs are inspectable.
- Design every task so it can be verified with Swift package tests, fixture
  inputs, or a RA11y fastlane dry run against already-captured screenshots.

## Workstream Map

| Stream | Goal | First deliverable |
|---|---|---|
| SAK-0 Foundation | Create the local package and CLI skeleton | `ScreenAuditKit/Package.swift`, library target, executable target, tests |
| SAK-1 Contracts | Define portable screenshot contract schema | Versioned JSON schema models and fixture tests |
| SAK-2 Evidence | Extract deterministic facts from PNG screenshots | Image metadata evidence and OCR transcript model |
| SAK-3 Rules | Convert evidence plus contracts into findings | Required/forbidden text, dimensions, and severity handling |
| SAK-4 Reports | Produce CI-usable outputs | JSON findings, Markdown summary, stable exit codes |
| SAK-5 RA11y Adapter | Wire RA11y screenshots into the package | RA11y contract directory and local validation command |
| SAK-6 Visual Heuristics | Add image quality and asset symptom checks | Alpha/matte/checkerboard/baseline warning rules |
| SAK-7 Flow | Validate ordered screenshot runs | Flow manifest, missing/duplicate state checks, Markdown graph |
| SAK-8 Pedagogy | Validate instructional copy progression | Generic pedagogy roles plus RA11y quest profile |
| SAK-9 CI/CD Hardening | Make integration stable beyond fastlane | JUnit/SARIF outputs and runner documentation |
| SAK-10 Extraction Readiness | Prepare for future external SPM repo | Public API audit, README, examples, versioning plan |

## Milestones

### Milestone A: Package Skeleton and Contract Core

Goal: create a local package that builds, tests, and can decode a minimal
contract without touching RA11y fastlane yet.

Tasks:

- SAK-0.1 Create local SPM package structure.
- SAK-0.2 Add `ScreenAuditKit` library product.
- SAK-0.3 Add `screenaudit` executable product.
- SAK-0.4 Add minimal XCTest targets with fixture directories.
- SAK-1.1 Define schema version model.
- SAK-1.2 Define screen contract model.
- SAK-1.3 Define device expectation model.
- SAK-1.4 Define OCR text expectation model.
- SAK-1.5 Add contract decoding tests with valid and invalid fixtures.
- SAK-4.1 Define finding, severity, evidence reference, and report models.

Acceptance checks:

- `swift test --package-path ScreenAuditKit` passes.
- CLI can print help without requiring screenshots.
- Contract decoding rejects unsupported schema versions with a clear error.
- No generic package file imports or references RA11y app modules.

### Milestone B: Deterministic Screenshot Validation MVP

Goal: validate an existing screenshot folder against portable contracts and
produce actionable JSON/Markdown output.

Tasks:

- SAK-2.1 Load PNG screenshots from explicit input paths.
- SAK-2.2 Extract dimensions, scale-independent pixel size, color model, and
  alpha presence.
- SAK-2.3 Add Vision OCR transcript extraction behind a narrow service boundary.
- SAK-2.4 Add OCR fixture fallback or injectable transcript source for tests.
- SAK-3.1 Implement required text rule.
- SAK-3.2 Implement forbidden text rule.
- SAK-3.3 Implement device dimension/orientation rule.
- SAK-3.4 Implement missing screenshot rule.
- SAK-3.5 Implement severity threshold and hard-failure decision.
- SAK-4.2 Implement JSON evidence report.
- SAK-4.3 Implement JSON findings report.
- SAK-4.4 Implement Markdown summary.
- SAK-4.5 Implement stable CLI exit codes.

Acceptance checks:

- Fixture tests cover pass, warning, hard fail, and configuration error paths.
- CLI can validate a local fixture screenshot folder without RA11y.
- Hard findings return non-zero exit status.
- Markdown summary includes screenshot path, screen ID, rule ID, severity, and
  evidence summary.

### Milestone C: RA11y First Adapter

Goal: prove the package against RA11y's current screenshot requirements while
keeping package code generic.

Tasks:

- SAK-5.1 Choose RA11y contract location.
- SAK-5.2 Create contracts for current screenshot catalog entries.
- SAK-5.3 Map existing route catalog scene IDs to generic screen IDs in data.
- SAK-5.4 Add a repo-local wrapper command or fastlane shell invocation.
- SAK-5.5 Keep existing `validate_screenshot_contract.sh` as a preflight until
  equivalent coverage exists in ScreenAuditKit.
- SAK-5.6 Write RA11y-specific README notes for running validation against
  existing `fastlane/screenshots/en-US`.
- SAK-5.7 Decide whether generated reports land under `build_results/` or a
  dedicated gitignored report directory.

Acceptance checks:

- Existing RA11y screenshots can be validated after capture.
- RA11y fastlane remains responsible for simulator selection and screenshot
  extraction.
- Package source contains no hardcoded RA11y screenshot names or paths.
- RA11y-specific contracts are reviewable as data.

### Milestone D: Visual and Asset Symptom Rules

Goal: catch the visual defects ADR-0005 calls out without making subjective
design taste a CI gate.

Tasks:

- SAK-6.1 Define protected, ignored, and critical regions in contracts. Done.
- SAK-6.2 Implement simple baseline diff metrics. Done.
- SAK-6.3 Implement suspicious opaque-border detection for source PNGs. Done.
- SAK-6.4 Implement rendered matte risk detection in critical regions. Done.
- SAK-6.5 Implement checkerboard-like pattern warning. Done.
- SAK-6.6 Implement low-confidence fallback-art warning hook. Done.
- SAK-6.7 Add overlay report generation for OCR boxes and failed regions. Done.
- SAK-6.8 Port or wrap RA11y Banishment asset expectations as data-driven rule
  configuration where practical. Done.

Acceptance checks:

- Asset symptom rules default to warnings unless contract severity overrides
  make them hard failures.
- Baseline comparisons support ignored volatile regions. Verified.
- Overlays are written only to repo-local output paths during RA11y runs.
- Tests use authored fixtures or mechanical image fixtures, not procedural
  quest art.

Implementation notes:

- Added contract support for protected/ignored visual regions.
- Added optional baseline expectation with reference path and mismatch threshold.
- Added `--baselines <dir>` support to `screenaudit validate`.
- Added deterministic PNG baseline comparison with ignored-region support.
- Added baseline difference findings, defaulting to warning severity.
- Added PNG transparency inspection for suspicious opaque borders around
  transparent interior pixels.
- Added `suspiciousOpaqueBorder` findings, defaulting to warning severity.
- Added critical-region contract support and rendered screenshot matte-risk
  inspection for flat white, black, or gray blocks.
- Added `renderedMatteRisk` findings, defaulting to warning severity.
- Added checkerboard-like region inspection for rendered transparency artifacts.
- Added `checkerboardPatternRisk` findings, defaulting to warning severity.
- Added contract-driven fallback art confidence facts.
- Added `lowConfidenceFallbackArt` findings, defaulting to warning severity.
- Added overlay PNG generation for screens with findings, using configured
  ignored, protected, and critical regions or a full-screen fallback outline.
- Added RA11y Banishment screen contract metadata for warning-only fallback art
  confidence review and critical art overlay regions.
- Added RA11y asset provenance metadata so fallback-art warnings explain source,
  authoring status, source quality, known risks, and supporting evidence.
- Added tests with mechanically generated tiny PNG fixtures.
- Verified `swift test --package-path ScreenAuditKit`.
- Verified `utility/validate_screen_audit.sh` still passes without baselines for
  current RA11y screenshot contracts.

### Milestone E: Flow Validation

Goal: validate ordered screenshot sets as a coherent user journey rather than
isolated files.

Tasks:

- SAK-7.1 Define flow contract model. Done.
- SAK-7.2 Define ordered run manifest model. Deferred; current implementation
  derives observed steps from screenshot evidence for deterministic folder runs.
- SAK-7.3 Implement missing step rule. Done.
- SAK-7.4 Implement duplicate/stuck state warning. Partially done; duplicate
  screen references in declared flows are warning findings.
- SAK-7.5 Implement expected previous/next transition checks.
- SAK-7.6 Generate Markdown flow summary. Done.
- SAK-7.7 Generate optional Mermaid graph.
- SAK-7.8 Add RA11y quest flow contracts for hub, VoiceOver required, first run,
  Enchanter, Dungeon, Resonance, and Banishment screenshot groups. Partially
  done for home/VoiceOver gate, Enchanter, Dungeon, and Banishment.

Acceptance checks:

- Flow validation can run on a folder with only metadata and screenshots.
- Missing required states fail deterministically. Verified.
- Duplicate/stuck findings include the flow ID and duplicated screen reference.
- Mermaid output is advisory report content, not required for CI pass/fail.

Implementation notes:

- Added top-level `flows` to the ScreenAuditKit contract schema.
- Added `ScreenAuditFlowEvaluator`, `ScreenAuditFlowReport`, and flow step
  status output.
- Added flow findings for unknown screen references, missing required steps,
  and duplicate declared steps.
- Added `flow.json` and `flow-summary.md` report output.
- Added RA11y flow contracts for home/VoiceOver gate, Enchanter Trial, Dungeon
  Scroll Hunt, and The Banishment.
- Verified `swift test --package-path ScreenAuditKit`.
- Verified `bash utility/validate_screen_audit.sh` across 4 existing screenshot
  folders.

### Milestone F: Pedagogy and Copy Progression

Goal: validate whether ordered screenshots teach the intended skill progression
using explicit metadata and OCR evidence.

Tasks:

- SAK-8.1 Define generic pedagogy roles: introduce, reinforce, practice, test,
  conclude.
- SAK-8.2 Define copy expectation model for lesson phrases, gesture terms, and
  forbidden scaffolding.
- SAK-8.3 Implement required lesson phrase rule.
- SAK-8.4 Implement forbidden later-stage scaffolding rule.
- SAK-8.5 Implement contradictory gesture wording rule.
- SAK-8.6 Implement result reinforcement rule.
- SAK-8.7 Define RA11y quest pedagogy profile using generic roles.
- SAK-8.8 Add Markdown pedagogy summary grouped by flow.

Acceptance checks:

- Pedagogy rules are deterministic and source-backed.
- Findings cite contract IDs and OCR evidence.
- RA11y-specific wording lives in RA11y contract/profile data.
- Optional reasoning summaries are not required for pass/fail.

### Milestone G: CI/CD and Distribution Hardening

Goal: make ScreenAuditKit reliable as a package and useful outside RA11y.

Tasks:

- SAK-9.1 Add JUnit XML report output.
- SAK-9.2 Add SARIF report output.
- SAK-9.3 Document fastlane integration.
- SAK-9.4 Document generic shell integration.
- SAK-9.5 Document GitHub Actions artifact/report pattern.
- SAK-9.6 Document Xcode Cloud artifact/report pattern.
- SAK-9.7 Document Bitrise/Buildkite/CircleCI/Jenkins invocation pattern.
- SAK-9.8 Add package-level README with minimal non-RA11y example.
- SAK-9.9 Audit public API surface before considering external repository move.
- SAK-10.1 Decide package name, license, versioning, and repository ownership.

Acceptance checks:

- At least one non-fastlane invocation is documented and tested with fixtures.
- JUnit output can represent hard failures as test failures.
- SARIF output includes rule IDs and artifact locations.
- README clearly marks RA11y as an example consumer, not a required convention.

## Initial Ticket Backlog

### SAK-0.1 Create local SPM package structure

Status: Done

User story:
As a maintainer, I want `ScreenAuditKit` to exist as a local package so future
validation work lands behind a reusable boundary from the beginning.

Requirements:

- Add `ScreenAuditKit/Package.swift`.
- Add `Sources/ScreenAuditKit`.
- Add `Sources/screenaudit`.
- Add `Tests/ScreenAuditKitTests`.
- Add `Tests/ScreenAuditCLITests`.
- Add an initial README.
- Add the package to `RA11y.xcworkspace`.
- Update `memlog/DirectoryTree.txt`.

Acceptance criteria:

- `swift test --package-path ScreenAuditKit` passes.
- `swift run --package-path ScreenAuditKit screenaudit --help` exits cleanly.
- The package has no third-party dependencies.

Implementation notes:

- Added `ScreenAuditKit` as a local package in `RA11y.xcworkspace`.
- Added `ScreenAuditKit` library and `screenaudit` executable products.
- Added initial package and CLI tests.
- Verified `swift test --package-path ScreenAuditKit`.
- Verified `swift run --package-path ScreenAuditKit screenaudit --help`.

### SAK-1.1 Define versioned contract schema models

Status: Done

User story:
As a package consumer, I want contracts to declare their schema version so
future package changes fail clearly instead of misreading validation intent.

Requirements:

- Define a top-level contract collection model.
- Define `schemaVersion`.
- Define screen ID, filename, device expectations, text expectations, roles,
  and severity overrides.
- Decode from JSON.
- Emit helpful errors for unsupported schema versions.

Acceptance criteria:

- Valid fixture decodes.
- Missing required fields fail with actionable errors.
- Unsupported schema version fails before rule evaluation.

Implementation notes:

- Added versioned JSON contract models under `ScreenAuditKit/Sources/ScreenAuditKit/Contracts/`.
- Added schema version, screen ID, filename, device expectations, text
  expectations, roles, pedagogy roles, and severity overrides.
- Added fixture tests for valid contracts, unsupported schema versions, and
  missing required screen fields.
- Verified `swift test --package-path ScreenAuditKit`.

### SAK-2.1 Build screenshot evidence extraction MVP

Status: Done

User story:
As a CI runner, I want deterministic facts extracted from screenshots so rules
can evaluate evidence instead of guessing from filenames alone.

Requirements:

- Load PNG files by explicit path.
- Extract pixel width and height.
- Detect alpha channel presence.
- Preserve screenshot path and screen ID in evidence.
- Keep OCR service injectable so tests do not depend on Vision output.

Acceptance criteria:

- Fixture PNG evidence reports include dimensions and alpha status.
- Non-PNG or unreadable image paths produce input errors.
- Tests can run without relying on live OCR.

Implementation notes:

- Added screenshot evidence models under `ScreenAuditKit/Sources/ScreenAuditKit/Evidence/`.
- Added PNG metadata extraction using ImageIO/CoreGraphics.
- Added path-based and data-based extraction.
- Added injectable OCR recognizer boundary with a no-op default.
- Added evidence tests using a small in-test transparent PNG fixture.
- Verified `swift test --package-path ScreenAuditKit`.

### SAK-3.1 Implement deterministic text and dimension rules

Status: Done

User story:
As a reviewer, I want required text, forbidden text, and dimensions validated
deterministically so obvious screenshot drift fails before manual review.

Requirements:

- Evaluate required OCR strings.
- Evaluate forbidden OCR strings.
- Evaluate expected dimensions or orientation.
- Return rule ID, severity, confidence, and evidence reference.

Acceptance criteria:

- Missing required text can be configured as a hard failure.
- Forbidden text can be configured as a hard failure or warning.
- Dimension mismatch includes actual and expected values.

Implementation notes:

- Added deterministic rule models under `ScreenAuditKit/Sources/ScreenAuditKit/Rules/`.
- Added rule IDs, findings, severities, confidence, and evidence references.
- Added required text, forbidden text, and dimension mismatch evaluation.
- Added tests for matching contracts, required text failures, forbidden text
  severity overrides, and dimension mismatches.
- Verified `swift test --package-path ScreenAuditKit`.

### SAK-4.1 Implement CLI reports and exit codes

Status: Done

User story:
As a CI integrator, I want stable outputs and exit codes so the tool can plug
into fastlane or any other runner without custom parsing.

Requirements:

- Add `screenaudit validate`.
- Accept `--screenshots`, `--contracts`, and `--output`.
- Write JSON evidence report.
- Write JSON findings report.
- Write Markdown summary.
- Exit with stable codes for success, hard findings, usage errors, input errors,
  and runtime errors.

Acceptance criteria:

- Fixture validation success exits `0`.
- Fixture hard failure exits `1`.
- Missing input directory exits with input error code.
- Markdown report is readable without opening JSON.

Implementation notes:

- Added `screenaudit validate --screenshots <dir> --contracts <file> --output <dir>`.
- Added filesystem validation orchestration for contract loading, screenshot
  evidence extraction, rule evaluation, and report writing.
- Added JSON evidence report, JSON findings report, and Markdown summary output.
- Added stable exit-code mapping for success, hard findings, usage errors, input
  errors, and runtime errors.
- Added CLI validation tests for success, hard failure, and missing input.
- Verified `swift test --package-path ScreenAuditKit`.

### SAK-5.1 Create RA11y first contract set

Status: Done

User story:
As the RA11y maintainer, I want the current screenshot route catalog represented
as data contracts so ScreenAuditKit proves useful against the real app.

Requirements:

- Choose RA11y contract directory.
- Add contract entries for current screenshot filenames.
- Include screen IDs, required text anchors, device expectations, flow roles, and
  pedagogy roles where known.
- Avoid changing screenshot capture behavior in the same task.

Acceptance criteria:

- RA11y contracts decode through ScreenAuditKit.
- Existing screenshot folders can be validated manually.
- Unknown or incomplete contracts are marked explicitly rather than silently
  skipped.

Implementation notes:

- Added `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json`.
- Represented the current screenshot route catalog as ScreenAuditKit screen
  contracts with scene IDs, filenames, device dimensions, screen roles, and
  pedagogy roles.
- Added `utility/validate_screen_audit.sh` as the repo-local wrapper command.
- Added `fastlane ios screen_audit` as the fastlane adapter lane.
- Documented local and fastlane adapter commands in `ScreenAuditKit/README.md`
  and `fastlane/README.md`.
- Chose `build_results/screen-audit/` for generated report output.
- Updated dimension validation so multiple device expectations are alternatives
  rather than cumulative requirements.
- Validated committed `docs/screenshots/en-US` screenshot folders with
  `utility/validate_screen_audit.sh`; all completed without hard failures.
- Verified `swift test --package-path ScreenAuditKit`.

## Dependency Order

1. SAK-0.1
2. SAK-1.1 through SAK-1.5
3. SAK-2.1 through SAK-2.4
4. SAK-3.1 through SAK-3.5
5. SAK-4.1 through SAK-4.5
6. SAK-5.1 through SAK-5.7
7. SAK-6 visual heuristics
8. SAK-7 flow validation
9. SAK-8 pedagogy validation
10. SAK-9 and SAK-10 hardening/extraction work

## Open Decisions

- Final package name: `ScreenAuditKit`, `ScreenshotAuditKit`, or another name.
- Exact contract directory for RA11y data.
- Whether RA11y report output should be under `build_results/screen-audit/` or a
  dedicated gitignored directory.
- Minimum supported macOS version for Vision OCR and optional Foundation Models.
- Whether baseline images should live under `docs/screenshots`, a new
  `ScreenAuditBaselines`, or app-specific contract folders.
- Whether package CLI should use subcommands from day one or a single `validate`
  mode until the surface grows.
- Whether JUnit/SARIF should wait until after RA11y adoption or ship in the MVP.

## First Implementation Recommendation

Start with SAK-0.1 through SAK-4.1 before touching fastlane. That gives us a
real package boundary, a testable schema, deterministic rules, and a CLI contract.
Then add RA11y contracts and one fastlane call site as SAK-5. This sequence keeps
the local package honest: if it cannot validate fixture screenshots without
RA11y, it is not yet drag-and-drop.
