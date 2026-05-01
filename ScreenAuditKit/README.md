# ScreenAuditKit

A local Swift Package for deterministic screenshot validation. RA11y is the first
consumer, but the package boundary is intentionally app-agnostic: screenshot folders
and JSON contracts are inputs; machine-readable reports, annotated PNG overlays, and
exit codes are outputs.

---

## Table of Contents

- [What It Does](#what-it-does)
- [How It Works](#how-it-works)
  - [Pipeline Overview](#pipeline-overview)
  - [Architecture](#architecture)
- [Package Products](#package-products)
- [Quick Start](#quick-start)
- [CLI Reference](#cli-reference)
- [Contract Format](#contract-format)
  - [Top-Level Fields](#top-level-fields)
  - [Screen Contract](#screen-contract)
  - [Regions](#regions)
  - [Asset Provenance](#asset-provenance)
- [Rules and Findings](#rules-and-findings)
- [Visual Inspectors](#visual-inspectors)
  - [Transparency Inspector](#transparency-inspector)
  - [Rendered Matte Inspector](#rendered-matte-inspector)
  - [Checkerboard Inspector](#checkerboard-inspector)
  - [Baseline Comparator](#baseline-comparator)
- [Reports](#reports)
  - [evidence.json](#evidencejson)
  - [findings.json](#findingsjson)
  - [summary.md](#summarymd)
  - [Overlay PNGs](#overlay-pngs)
- [RA11y Integration](#ra11y-integration)
  - [Input Sources](#input-sources)
  - [Running via Shell Script](#running-via-shell-script)
  - [Running via Fastlane](#running-via-fastlane)
- [OCR Boundary](#ocr-boundary)
- [Severity Model](#severity-model)
- [Exit Codes](#exit-codes)
- [Testing](#testing)
- [Current State](#current-state)
- [Roadmap](#roadmap)

---

## What It Does

ScreenAuditKit answers the question: **"Are these screenshots correct?"** It
validates screenshot PNGs against a JSON contract that describes what each screen
is supposed to look like — text that must appear, pixel dimensions, named regions,
visual artifact thresholds, and optional pixel-diff baselines.

**Problems it catches:**

| Problem | Detection mechanism |
|---|---|
| Required UI copy missing from a screen | OCR text matching |
| Forbidden copy present (debug labels, placeholder text) | OCR text matching |
| Screenshot is the wrong size | Pixel dimension rules |
| Transparent sprite rendered with a flat grey matte | Matte inspector (critical regions) |
| Checkerboard transparency artifact from bad PNG export | Checkerboard inspector (critical regions) |
| Opaque rectangular border around a transparent asset | Edge-opacity inspector |
| Screenshot drifted significantly from a known-good baseline | Pixel-diff baseline comparison |
| LLM-generated or placeholder art shipped at low confidence | Asset provenance rules |

Every finding is written to `findings.json` with a rule ID, severity, confidence
score, and a human-readable message. Findings classified as `.error` cause the CLI
to exit non-zero for CI/CD gating.

---

## How It Works

### Pipeline Overview

```
screenshots/          contracts.json         provenance.json (optional)
     │                      │                        │
     ▼                      ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ScreenAuditValidator                         │
│                                                                 │
│  1. Parse & validate contract schema                            │
│  2. Extract PNG evidence (dimensions, alpha, OCR transcript)    │
│  3. Evaluate deterministic rules against evidence               │
│  4. Run visual inspectors on critical/protected regions         │
│  5. Compare to pixel-diff baselines (if configured)             │
│  6. Write evidence.json, findings.json, summary.md              │
│  7. Render annotated PNG overlays for findings                  │
└─────────────────────────────────────────────────────────────────┘
     │
     ▼
build_results/screen-audit/<device>/
  ├── evidence.json          ← what was extracted from each PNG
  ├── findings.json          ← all rule violations
  ├── summary.md             ← human-readable review summary
  └── overlays/
      ├── <screen>.png       ← screenshot annotated with region boxes
      ├── <screen>.json      ← machine-readable overlay sidecar
      └── <screen>.md        ← explanation sidecar for each finding
```

### Architecture

The package is divided into six functional layers, each in its own source file:

| Layer | File | Responsibility |
|---|---|---|
| **Contracts** | `ScreenAuditContracts.swift` | JSON schema for describing expected screen state |
| **Evidence** | `ScreenAuditEvidence.swift` | Extract deterministic facts from PNG files |
| **Rules** | `ScreenAuditRules.swift` | Evaluate contracts against evidence; produce findings |
| **Validation** | `ScreenAuditValidation.swift` | Orchestrate all layers end-to-end |
| **Reports** | `ScreenAuditReports.swift` | Write JSON + Markdown output files |
| **Visual** | `Visual/*.swift` | Four pluggable pixel-level inspectors |

---

## Package Products

```swift
// Package.swift (swift-tools-version: 6.1, macOS 15+)
products: [
    .library(name: "ScreenAuditKit", ...),    // import in custom tooling
    .executable(name: "screenaudit", ...),    // CLI binary for local/CI use
]
```

No external dependencies — the package uses only Foundation and CoreGraphics.

---

## Quick Start

```sh
# Run tests
swift test --package-path ScreenAuditKit

# Get help
swift run --package-path ScreenAuditKit screenaudit --help

# Run RA11y adapter (validates all device folders)
bash utility/validate_screen_audit.sh

# Run via Fastlane
bundle exec fastlane ios screen_audit
```

---

## CLI Reference

```
USAGE: screenaudit validate [OPTIONS]

OPTIONS:
  --screenshots <dir>   Directory of PNG files to audit (one per screen)
  --contracts   <file>  Path to ScreenAuditContracts.json
  --output      <dir>   Directory for evidence.json, findings.json, summary.md,
                        and overlays/
  --baselines   <dir>   (Optional) Directory of baseline PNGs for pixel-diff
  --help                Show this message
```

**Example:**

```sh
swift run --package-path ScreenAuditKit screenaudit validate \
  --screenshots docs/screenshots/en-US/iPhone-16 \
  --contracts RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json \
  --output build_results/screen-audit/iPhone-16
```

---

## Contract Format

Contracts live at `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json` and are
versioned under source control alongside the codebase they describe.

### Top-Level Fields

```json
{
  "schemaVersion": 1,
  "projectName": "RA11y",
  "assetProvenancePath": "ScreenAuditAssetProvenance.json",
  "screens": [ ... ]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `schemaVersion` | `Int` | Yes | Must equal `1` (current supported version) |
| `projectName` | `String` | Yes | Human-readable project label used in reports |
| `assetProvenancePath` | `String?` | No | Path to the asset provenance JSON (relative to the contract file) |
| `screens` | `[ScreenContract]` | Yes | One entry per screenshot filename |

### Screen Contract

```json
{
  "id": "hub",
  "filename": "hub.png",
  "devices": [
    {
      "label": "iPhone 16",
      "family": "iPhone",
      "pixelWidth": 1179,
      "pixelHeight": 2556,
      "orientation": "portrait"
    }
  ],
  "text": {
    "required": ["Play", "Banishment", "The Enchanter's Trial"],
    "optional": ["Resume"],
    "forbidden": ["TODO", "Placeholder", "DEBUG"]
  },
  "role": "entry",
  "pedagogyRole": null,
  "regions": {
    "protected": [],
    "ignored": [{ "name": "statusBar", "x": 0, "y": 0, "width": 1179, "height": 54 }],
    "critical": [{ "name": "questCard", "x": 40, "y": 320, "width": 1099, "height": 240,
                   "coordinateSpace": { "width": 1179, "height": 2556 } }]
  },
  "baseline": {
    "referencePath": "baselines/hub.png",
    "maxMismatchRatio": 0.05
  },
  "assets": {
    "fallbackArt": [
      {
        "name": "enchanter_tower_shelf_bg",
        "confidence": 0.95,
        "minimumConfidence": 0.75,
        "provenanceID": "enchanter-bg-v1"
      }
    ]
  },
  "severityOverrides": {
    "dimensionMismatch": "warning"
  }
}
```

| Field | Description |
|---|---|
| `id` | Unique identifier used in finding references and overlay filenames |
| `filename` | PNG filename expected in the screenshots directory |
| `devices` | Expected device label, family, pixel dimensions, and orientation |
| `text.required` | Strings that must appear in the OCR transcript |
| `text.optional` | Strings that may appear; logged but not a failure |
| `text.forbidden` | Strings that must NOT appear (placeholder text, debug labels) |
| `role` | Semantic screen role: `entry`, `tutorial`, `play`, `success`, `failure`, `result` |
| `pedagogyRole` | Teaching intent: `introduce`, `reinforce`, `practice`, `test`, `conclude` |
| `regions` | Named pixel regions for visual inspection (see below) |
| `baseline` | Optional baseline PNG + max mismatch threshold for pixel-diff |
| `assets.fallbackArt` | Asset confidence expectations (triggers low-confidence finding) |
| `severityOverrides` | Promote or demote severity for specific rule IDs on this screen |

### Regions

Regions let you tell the inspector which pixels matter.

| Region type | Color in overlays | Purpose |
|---|---|---|
| `protected` | Blue | Pixels that must not change unexpectedly; checked against baseline |
| `ignored` | Amber | Pixels excluded from baseline comparison (status bars, timestamps, badges) |
| `critical` | Red | Pixels inspected by matte and checkerboard detectors |

Regions may declare a `coordinateSpace` — a reference `{width, height}` that the
region coordinates were authored against. The validator automatically scales the
region to the actual screenshot dimensions at runtime, so contracts remain stable
when screenshots are captured at different resolutions.

### Asset Provenance

The optional `ScreenAuditAssetProvenance.json` file tracks the source and quality
of each visual asset, enabling the validator to warn when placeholder or low-quality
art is still in production screenshots.

```json
{
  "assets": [
    {
      "id": "enchanter-bg-v1",
      "name": "enchanter_tower_shelf_bg",
      "source": "llmAuthored",
      "authoringStatus": "final",
      "sourceQuality": "production",
      "knownRisks": [],
      "evidence": ["Verified via validate_banishment_assets.sh"],
      "note": null
    }
  ]
}
```

| `source` values | Description |
|---|---|
| `humanAuthored` | Hand-made by a designer |
| `llmAuthored` | Generated by an LLM image tool |
| `mockupCrop` | Cropped from a UX mockup |
| `placeholder` | Temporary art, should not ship |
| `procedural` | Code-drawn (no raster file) |

| `authoringStatus` values | Description |
|---|---|
| `final` | Production-ready |
| `reviewNeeded` | Requires design sign-off |
| `temporary` | Intentional placeholder |

---

## Rules and Findings

Each finding has a `ruleID`, `severity`, `confidence` (0.0–1.0), `message`, and
an `evidence` reference pointing to the screen ID and file path that triggered it.

| Rule ID | Default Severity | Trigger |
|---|---|---|
| `missingScreenshot` | `.error` | Screenshot file not found in the screenshots directory |
| `requiredTextMissing` | `.error` | A `text.required` string was not found in the OCR transcript |
| `forbiddenTextPresent` | `.error` | A `text.forbidden` string was found in the OCR transcript |
| `dimensionMismatch` | `.error` | PNG pixel dimensions do not match the contract's expected size |
| `baselineDifferenceExceeded` | `.warning` | Pixel-diff mismatch ratio exceeds `maxMismatchRatio` |
| `suspiciousOpaqueBorder` | `.warning` | Edge pixels are fully opaque while interior pixels are transparent |
| `renderedMatteRisk` | `.warning` | Critical region contains a large flat-neutral block (grey/white/black matte) |
| `checkerboardPatternRisk` | `.warning` | Critical region contains a checkerboard transparency artifact |
| `lowConfidenceFallbackArt` | `.info` | Asset confidence is below `minimumConfidence` per provenance record |

Severity can be overridden per screen using `severityOverrides` in the contract.
Any finding with severity `.error` causes the CLI to exit with code `1`.

---

## Visual Inspectors

The four visual inspectors operate on pixel data using CoreGraphics. They are
separate from the rule evaluator and produce findings only via their
`findingIfNeeded(...)` method.

### Transparency Inspector

**File:** `Visual/ScreenAuditTransparencyInspector.swift`

Checks whether a PNG has a suspicious pattern where the outer edge pixels are
fully opaque but the interior pixels are transparent — a hallmark of a rasterized
matte bed. This is distinct from the rendered-matte inspector: the transparency
inspector operates on the entire image's edge, not a named region.

**How it works:**
1. Decode PNG pixel data via CoreGraphics.
2. Sample every pixel on the four outer edges (top, bottom, left, right rows/columns).
3. Count pixels where `alpha >= 250` (fully opaque).
4. Count interior pixels where `alpha < 200` (transparent).
5. Flag as suspicious when opaque-edge ratio ≥ 0.95 **and** transparent interior count > 0.

**Configurable threshold:** `minimumOpaqueEdgeRatio` (default 0.95)

### Rendered Matte Inspector

**File:** `Visual/ScreenAuditRenderedMatteInspector.swift`

Detects large flat white, black, or mid-grey blocks inside a named `critical`
region. A rendered matte occurs when a sprite PNG is exported with a solid
background rather than true transparency, or when SwiftUI composites an image
over an unexpected solid colour.

**How it works:**
1. Clip the screenshot to the named critical region.
2. For each sampled pixel, compute `max(r,g,b) - min(r,g,b)` (saturation span).
3. Consider a pixel "matte-like" when: span ≤ 8 (nearly neutral) **and** the
   brightness falls in white (≥ 230), near-black (≤ 30), or mid-grey (100–160) ranges.
4. Flag as a risk when matte-like ratio ≥ 0.85 across the region.

**Configurable threshold:** `minimumMatteLikeRatio` (default 0.85)

### Checkerboard Inspector

**File:** `Visual/ScreenAuditCheckerboardInspector.swift`

Detects checkerboard-style patterns in a critical region — the classic sign of
an accidentally transparent PNG being composited over a checkerboard background,
or a texture bake that leaked checker geometry.

**How it works:**
1. Divide the region into a grid of `cellSize × cellSize` cells (default 8px).
2. Compute the average colour of each cell.
3. For every 2×2 block of cells, check whether diagonally opposite cells match
   (color distance ≤ `maximumSameColorDistance`) and orthogonally adjacent cells
   differ (color distance ≥ `minimumDifferentColorDistance`).
4. Flag as a risk when the ratio of alternating 2×2 blocks ≥ 0.80.

**Configurable thresholds:**
- `cellSize` (default 8) — grid granularity
- `minimumAlternatingRatio` (default 0.80) — how much of the region must alternate
- `maximumSameColorDistance` (default 10) — diagonal cells considered "same"
- `minimumDifferentColorDistance` (default 24) — orthogonal cells considered "different"

### Baseline Comparator

**File:** `Visual/ScreenAuditBaselineComparator.swift`

Performs a pixel-by-pixel comparison between a screenshot and a reference baseline
PNG. Supports ignored regions (e.g., to exclude timestamps or animated badges).

**How it works:**
1. Decode both images to raw pixel buffers.
2. For each pixel coordinate, skip if it falls inside any `ignored` region.
3. Compare RGBA values; mark as mismatched when any channel differs by more than
   a small tolerance (hardcoded to exact match currently).
4. Compute `mismatchedPixels / comparedPixels` as the mismatch ratio.
5. Produce a finding when the ratio exceeds `maxMismatchRatio` from the contract.

---

## Reports

All output is written to the `--output` directory (one directory per device when
using the RA11y shell adapter).

### evidence.json

Machine-readable facts extracted from every screenshot.

```json
{
  "reportVersion": 1,
  "projectName": "RA11y",
  "screenshots": [
    {
      "screenID": "hub",
      "path": "/path/to/hub.png",
      "pixelWidth": 1179,
      "pixelHeight": 2556,
      "hasAlpha": false,
      "ocrTranscript": { "fullText": "Play\nThe Enchanter's Trial\nBanishment..." }
    }
  ]
}
```

### findings.json

Machine-readable violations. This is the primary CI/CD artifact.

```json
{
  "reportVersion": 1,
  "projectName": "RA11y",
  "findings": [
    {
      "ruleID": "requiredTextMissing",
      "severity": "error",
      "confidence": 1.0,
      "message": "Required text 'Banishment' not found in OCR transcript for hub.",
      "evidence": {
        "screenID": "hub",
        "path": "/path/to/hub.png",
        "excerpt": "OCR transcript: 'Play\nThe Enchanter\\'s Trial...'"
      }
    }
  ]
}
```

`findingsReport.hasHardFailures` is `true` when any finding has severity `.error`.
The CLI exits non-zero in this case.

### summary.md

A Markdown summary formatted for human review in pull requests and build logs.
Lists all findings grouped by severity with screen ID, rule, and message.

### Overlay PNGs

For each screen that has findings or named regions, an annotated PNG overlay is
rendered with colored stroke rectangles:

| Color | Region type |
|---|---|
| Red | `critical` regions |
| Blue | `protected` regions |
| Amber | `ignored` regions |

A JSON sidecar (`<screen>.json`) and Markdown explanation (`<screen>.md`) are
written alongside each overlay PNG.

---

## RA11y Integration

### Input Sources

| File | Role |
|---|---|
| `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json` | Screen contracts (source of truth) |
| `RA11y-iOS/RA11y-iOSUITests/ScreenAuditAssetProvenance.json` | Asset provenance metadata |
| `docs/screenshots/en-US/<device>/` | Screenshots captured by Fastlane |
| `build_results/screen-audit/` | Output directory for all reports |

### Running via Shell Script

```sh
# Validate all device folders under docs/screenshots/en-US/
bash utility/validate_screen_audit.sh

# Override screenshot source and output directories:
bash utility/validate_screen_audit.sh /path/to/screenshots /path/to/output
```

The script iterates over each device subfolder and runs `screenaudit validate`
once per device. Exit code is non-zero if any device folder has hard failures.

### Running via Fastlane

```sh
bundle exec fastlane ios screen_audit
```

Defined in `fastlane/Fastfile`, this lane calls `validate_screen_audit.sh`
and is wired into the standard release pipeline.

---

## OCR Boundary

Text validation relies on an injectable `ScreenAuditOCRRecognizing` protocol:

```swift
public protocol ScreenAuditOCRRecognizing {
    func recognizeText(inPNGData data: Data, path: String) throws -> ScreenAuditOCRTranscript
}
```

The default implementation is a **no-op** (`ScreenAuditNoOpOCRRecognizer`) that
returns an empty transcript. This keeps the package dependency-free and the test
suite fast, but means `text.required` and `text.forbidden` rules are not enforced
until a real OCR recognizer is injected.

**Planned implementation:** Vision framework (`VNRecognizeTextRequest`) wired in
from the RA11y UI test bundle, where the `Vision` framework is available on-device.

---

## Severity Model

| Severity | Meaning | CLI effect |
|---|---|---|
| `.error` | Hard failure — rule is definitely violated | `exit(1)` |
| `.warning` | Soft failure — likely issue requiring human review | Reported, does not fail CI |
| `.info` | Advisory — low-confidence observation | Reported only |

Use `severityOverrides` in the contract to tune severity per screen:

```json
"severityOverrides": {
  "dimensionMismatch": "warning",
  "renderedMatteRisk": "error"
}
```

---

## Exit Codes

| Code | Constant | Meaning |
|---|---|---|
| `0` | `success` | All contracts passed (no `.error` findings) |
| `1` | `validationFailed` | One or more `.error` findings |
| `2` | `usageError` | Bad CLI arguments or missing required options |
| `3` | `inputError` | Contract file unreadable, schema version unsupported, or PNG unreadable |
| `4` | `runtimeError` | Unexpected failure during analysis |

---

## Testing

```sh
swift test --package-path ScreenAuditKit
```

Tests are split across two targets:

**`ScreenAuditKitTests`** — Library unit tests (nine files, ~1 100 lines):

| Test file | What it covers |
|---|---|
| `ScreenAuditContractTests` | JSON decoding, schema validation, required fields |
| `ScreenAuditEvidenceTests` | PNG metadata extraction, alpha detection |
| `ScreenAuditRuleTests` | Required/forbidden text, dimension checks, fallback art |
| `ScreenAuditBaselineTests` | Pixel-diff accuracy, ignored regions, threshold clamping |
| `ScreenAuditTransparencyTests` | Opaque-border heuristics, edge cases |
| `ScreenAuditRenderedMatteTests` | Flat-matte detection in synthetic regions |
| `ScreenAuditCheckerboardTests` | Alternating-pattern detection thresholds |
| `ScreenAuditKitTests` | Package version and help-text smoke tests |

**`ScreenAuditCLITests`** — CLI argument parsing and end-to-end integration
(~250 lines): validates all flag combinations, missing-argument errors, and
the full validate command flow with fixture data.

**Test fixtures** live in `Tests/ScreenAuditKitTests/Fixtures/` and include valid
contracts, unsupported schema versions, and missing-field contracts.

---

## Current State

`v0.1.0-local` — production-ready for the RA11y project.

| Capability | Status |
|---|---|
| Contract schema v1 parsing and validation | ✅ Shipped |
| PNG evidence extraction (dimensions, alpha) | ✅ Shipped |
| OCR boundary (injectable protocol, no-op default) | ✅ Shipped |
| Required / forbidden / optional text rules | ✅ Shipped (no-op until OCR injected) |
| Device dimension validation | ✅ Shipped |
| Responsive region scaling (coordinate spaces) | ✅ Shipped |
| Baseline pixel-diff comparison with ignored regions | ✅ Shipped |
| Transparency / opaque-border inspector | ✅ Shipped |
| Rendered-matte inspector (critical regions) | ✅ Shipped |
| Checkerboard-artifact inspector (critical regions) | ✅ Shipped |
| PNG overlay renderer with region annotations | ✅ Shipped |
| JSON + Markdown report output | ✅ Shipped |
| CLI (`screenaudit validate`) | ✅ Shipped |
| Shell adapter (`validate_screen_audit.sh`) | ✅ Shipped |
| Fastlane lane (`screen_audit`) | ✅ Shipped |
| Asset provenance tracking + low-confidence findings | ✅ Shipped |
| Per-screen severity overrides | ✅ Shipped |
| Vision OCR recognizer implementation | 🔲 Not yet |
| Multi-locale screenshot support | 🔲 Not yet |
| Dynamic Type / accessibility size variant contracts | 🔲 Not yet |
| CI badge / summary comment on pull requests | 🔲 Not yet |

---

## Roadmap

Priorities are tracked in `memlog/research/ScreenAuditKit-Workstream.md`.

### Near Term

**Real OCR via Vision framework.** Wire `VNRecognizeTextRequest` into the iOS
UI test bundle as a concrete `ScreenAuditOCRRecognizing` implementation. Until
this lands, `text.required` and `text.forbidden` rules produce no findings.

**Baseline management commands.** Add `screenaudit baseline accept` to promote
the current screenshots to the baseline directory, and `screenaudit baseline diff`
to preview mismatch overlays without running the full validation suite.

**Ignore-region coverage for dynamic content.** Contract tooling to declare
regions that contain dynamic or animated content (badges, live timers) so baseline
comparisons don't generate false positives.

### Medium Term

**Multi-locale contracts.** Support separate expected text sets per locale
(`en-US`, `es-419`, etc.) within a single contract so localised screenshot
folders can be validated against locale-specific strings.

**Dynamic Type variant validation.** Contracts for accessibility text-size
variants (e.g. AX5 Extra Large) to catch text clipping, layout overflow, and
missing scroll affordances.

**Dark mode / light mode parity contracts.** Express that a screen should exist
in two appearance variants and that key structural properties should match between
them.

**Programmatic severity budgets.** Allow a contract to declare maximum counts of
warnings or info findings before they escalate to errors, enabling gradual adoption
on legacy screens.

### Longer Term

**Multi-project package distribution.** Remove the RA11y-specific path assumptions
from the shell adapter and release as a standalone package that other projects can
add as a Swift Package dependency.

**Xcode plug-in integration.** Explore a build tool plug-in that captures
screenshots on simulator boot and feeds them to the validator without a separate
Fastlane invocation.

**Pull request comment integration.** A GitHub Actions step that posts a
`summary.md` as a PR comment and attaches overlay PNGs as build artifacts, giving
reviewers visual evidence inline.

**Diff-based baseline promotion workflow.** Tooling to review baseline diffs
interactively — approve, reject, or defer individual screen changes — and commit
the result in a single atomic git operation.

---

## Related Files

| File | Role |
|---|---|
| `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json` | Live screen contracts |
| `RA11y-iOS/RA11y-iOSUITests/ScreenAuditAssetProvenance.json` | Live asset provenance |
| `utility/validate_screen_audit.sh` | Shell adapter for local and CI use |
| `fastlane/Fastfile` (lane `screen_audit`) | Fastlane adapter |
| `memlog/research/ScreenAuditKit-Workstream.md` | Design notes and workstream log |
| `memlog/designRefactorTasks.md` | Open refactor tasks that affect screenshot contracts |
| `build_results/screen-audit/` | Runtime output (git-ignored) |
