# ADR-0002: AI-Assisted Screenshot Validation for Fastlane UI QA

Date: 2026-04-19
Status: Proposed

## Context

RA11y already captures deterministic screenshots through the fastlane `screenshots`
lane, the `-screenshotScene <sceneID>` boot path, and xcresult attachment
extraction. That solved the first-order reliability problem: getting the app to
produce the right PNG files for each intended screen.

However, the current pipeline still validates only that:

- the screenshot tests ran,
- the expected PNG files exist,
- the route catalog, test allowlist, and scene contract are aligned.

It does not validate whether the screenshots themselves are visually correct.
Examples of failures the current lane can miss:

- clipped or truncated UI,
- unreadable contrast,
- missing artwork that silently falls back to SF Symbols,
- wrong screen state rendered under the correct filename,
- incorrect spacing or layout regressions across device classes,
- stale content or score state in screenshots that should be deterministic,
- accessibility regressions where critical text is absent from the rendered UI.

The project goal is larger than screenshot capture. We want screenshot automation
to become a credible UI validation system that can:

- detect obvious visual regressions early,
- scale with more screens and platforms,
- produce actionable reports for developers and designers,
- remain deterministic enough for CI,
- preserve user privacy by preferring on-device analysis,
- optionally use Apple Intelligence to summarize or classify issues.

At the same time, we need to stay grounded in current platform capabilities.
Apple's Foundation Models framework is currently documented as an on-device
language framework focused on text generation, guided generation, and tool
calling. It is not currently documented as a direct multimodal screenshot input
API. Vision and VisionKit, by contrast, provide deterministic visual extraction
such as OCR, image classification, region detection, and document/image analysis.

Therefore, any near-term design that assumes "feed screenshot PNGs directly to
Foundation Models and get reliable visual QA" would be speculative and fragile.

## Decision

Adopt a layered screenshot-validation architecture for fastlane with the
following principles:

1. **Deterministic checks first**
   - The primary pass/fail gate remains rule-based and deterministic.
   - Use image metadata, OCR, layout heuristics, asset expectations, and baseline
     comparisons before any generative review.

2. **Vision as the perception layer**
   - Use Vision / VisionKit / CoreGraphics / ImageIO to extract structured facts
     from screenshots.
   - Treat this layer as the sensor system for text, regions, dimensions,
     saliency, and basic semantic image signals.

3. **Foundation Models as an optional reasoning layer**
   - If available on the machine, use Foundation Models only to interpret
     structured evidence and produce summaries, severity classifications, and
     likely-cause diagnoses.
   - Do not make the core CI pass/fail path depend on Foundation Models.

4. **Fastlane remains the orchestration layer**
   - Fastlane should capture screenshots, run deterministic validation, collect
     artifacts, and fail the lane when hard requirements are violated.
   - AI-assisted review should be integrated as a post-capture analysis stage,
     not as a replacement for screenshot capture.

5. **Contracts over guesswork**
   - Each screenshotable screen must have an explicit validation contract:
     expected scene ID, expected text anchors, optional allowed variance,
     critical controls, and per-device expectations.
   - Validation should reason from those contracts, not from brittle ad hoc
     prompt text.

6. **Progressive sophistication**
   - Build this in phases so each stage delivers value independently and remains
     debuggable.

## Proposed Architecture

### 1. Capture Stage

Existing components remain the source of truth:

- `fastlane/Fastfile`
- `RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift`
- `RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift`
- `RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md`
- `scripts/extract_screenshots.sh`

Output:

- screenshot PNGs
- xcresult bundles
- manifest / metadata

### 2. Deterministic Extraction Stage

Add a Swift-based analysis tool that consumes each screenshot and emits
structured evidence.

Recommended inputs:

- screenshot PNG path
- scene ID / filename
- device label
- validation contract for that scene

Recommended extracted evidence:

- image dimensions and orientation
- OCR transcript
- OCR text regions and bounding boxes
- detected major empty/blank regions
- mean brightness / contrast heuristics
- cropped-edge warnings near safe areas
- expected anchor text present / absent
- expected control count estimates
- optional pixel diff against baseline

Recommended frameworks:

- `Foundation`
- `ImageIO`
- `CoreGraphics`
- `Vision`
- `VisionKit` where useful on supported platforms

### 3. Rule Evaluation Stage

Create a deterministic validator that converts extracted evidence into hard
findings.

Examples of hard rules:

- required title text missing,
- screenshot dimensions do not match expected device family,
- large OCR bounding boxes exceed visible area,
- expected CTA not found,
- known scene-specific asset fallback detected,
- baseline diff exceeds threshold,
- contrast below threshold in critical text regions.

This stage should be fully CI-safe and not require Apple Intelligence.

### 4. Optional AI Review Stage

If `SystemLanguageModel.default` is available, run a local reasoning pass on the
structured evidence, not on raw pixels.

Responsibilities of the AI review stage:

- summarize findings in human-readable language,
- cluster multiple low-level signals into one likely issue,
- rank severity or confidence,
- suggest likely causes such as "missing asset", "layout overflow", or
  "deterministic state drift".

Non-responsibilities:

- do not decide the primary CI pass/fail outcome,
- do not replace deterministic rules,
- do not inspect raw screenshots without a supported multimodal API.

### 5. Reporting Stage

Produce machine-readable and human-readable outputs:

- JSON report for CI and downstream tooling,
- Markdown summary for PRs / artifacts,
- optional annotated overlay PNGs showing OCR boxes or failure regions.

## Fastlane Integration Strategy

Extend the current lane with an explicit validation phase after extraction.

Conceptual flow:

1. Capture screenshots.
2. Extract PNGs.
3. Run `validate_screenshot_contract.sh`.
4. Run new screenshot analyzer tool.
5. Fail lane if hard validation findings exist.
6. Upload reports and overlays as artifacts.
7. Optionally append AI summary if Foundation Models is available.

Possible lane structure:

- `screenshots`: capture only
- `screenshots_validate`: capture + deterministic validation
- `screenshots_review`: capture + validation + optional AI review
- `screenshots_quick`: one-device validation path for iteration

This preserves a clean separation between capture failures and visual QA
failures.

## Validation Contract Model

Introduce an explicit per-screen contract file rather than embedding all
validation assumptions in code comments.

Example contract dimensions:

- screenshot file name
- scene ID
- device families required
- required OCR strings
- optional OCR strings
- forbidden strings
- expected major regions
- baseline image path
- allowed pixel-diff threshold
- expected critical element count
- scene-specific heuristic toggles

Potential storage options:

- JSON in `RA11y-iOS/RA11y-iOSUITests/`
- YAML in `memlog/requirements/`
- Swift source if tight compile-time coupling is desired

Decision: prefer a machine-readable contract file checked into the repo, with
lightweight Swift decoding.

## Lofty Goals

The long-term ambition is a UI validation system that behaves like a structured,
on-device visual QA assistant.

Stretch goals include:

1. **Semantic screen verification**
   - Assert that a screenshot is not only present, but semantically the correct
     screen for its filename.

2. **Cross-device responsiveness analysis**
   - Detect when a screen passes on iPad but clips on small iPhone layouts.

3. **Accessibility-first visual QA**
   - Check rendered text visibility, OCR presence, contrast heuristics, and
     consistency between accessibility identifiers and visible content.

4. **Baseline-aware design drift detection**
   - Distinguish intentional design changes from accidental regressions.

5. **Artifact-backed PR review**
   - Produce reports that make UI regressions reviewable without manually opening
     every screenshot.

6. **Multi-platform expansion**
   - Reuse the same architecture for tvOS, and later macOS, with platform-specific
     scene contracts.

7. **Human-in-the-loop designer workflow**
   - Allow designers to update baselines, approve drift, and add new screen
     contracts without editing fastlane logic.

## Phased Implementation Plan

### Phase 0: Contract hardening

- Keep current screenshot scene contract as the routing source of truth.
- Add explicit validation contract files per screenshot.
- Retire legacy direct-route screenshot arguments once no longer needed.

### Phase 1: Deterministic validator MVP

Build a Swift executable, likely under `utility/` or as a small Swift package,
that performs:

- OCR extraction,
- required-text checks,
- image-size checks,
- blank-screen checks,
- optional baseline diffs,
- JSON report output.

This phase should be sufficient to catch major UI regressions without any AI.

### Phase 2: Heuristic layout analysis

Add richer screenshot heuristics:

- detect bottom-sheet/footer clipping,
- detect text overflow near edges,
- detect missing visual regions relative to baselines,
- detect likely placeholder/fallback imagery.

### Phase 3: Optional Foundation Models review

When available, feed the extracted evidence into Foundation Models and request a
structured summary such as:

- overall screen quality verdict,
- issue grouping,
- likely root causes,
- concise recommendations.

This output should be additive and non-blocking by default.

### Phase 4: CI / PR ergonomics

- emit Markdown summaries,
- upload annotated overlays,
- optionally post PR comments,
- track screenshot quality trends over time.

## Consequences

### Positive

- Moves screenshot automation from "capture only" to real UI QA.
- Preserves deterministic CI behavior by keeping hard checks rule-based.
- Leverages Apple-native frameworks and stays privacy-preserving.
- Creates a path to use Foundation Models responsibly without overcommitting to
  unsupported multimodal assumptions.
- Encourages better screen contracts and documentation discipline.

### Negative

- Adds nontrivial implementation complexity.
- OCR and heuristics will require tuning to avoid noisy failures.
- Baseline diffs can be brittle if the app intentionally evolves often.
- Foundation Models availability is hardware- and settings-dependent, so it
  cannot be assumed in all developer or CI environments.

## Alternatives Considered

### 1. Do nothing beyond current screenshot existence checks

Rejected.

This leaves the project exposed to visual regressions that are already known to
happen.

### 2. Depend entirely on Foundation Models for screenshot review

Rejected.

Current Apple documentation supports text generation, guided generation, and tool
calling, but not a documented direct screenshot-multimodal workflow suitable as
our primary validation engine.

### 3. Use only pixel diffing

Rejected.

Pixel diffing is useful but insufficient. It is too brittle on its own and does
not explain failures well.

### 4. Use only XCTest accessibility assertions instead of screenshot analysis

Rejected.

Accessibility assertions are necessary but not sufficient. They do not catch many
visual issues such as clipping, wrong artwork, spacing problems, or contrast
regressions.

## Open Questions

- Should the validation contract live beside UI tests or under requirements docs?
- Should baseline images be committed for every device or only canonical devices?
- Which findings should fail CI versus warn only?
- Should AI review be enabled locally by default or only in an explicit lane?
- How should designer-approved intentional visual changes update baselines?

## Follow-Ups

- Define the screenshot validation contract schema.
- Prototype a Swift screenshot analyzer executable using Vision OCR and image
  heuristics.
- Add a fastlane lane that runs deterministic screenshot validation after
  extraction.
- Evaluate whether Foundation Models materially improves issue triage once the
  deterministic evidence pipeline exists.
- Fold this workflow into PR review artifacts after the validator is reliable.

## References

- https://developer.apple.com/documentation/vision/
- https://developer.apple.com/documentation/vision/recognizing-text-in-images
- https://developer.apple.com/documentation/visionkit/imageanalysis
- https://developer.apple.com/documentation/FoundationModels?language=objc
- https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel?changes=_10_5
