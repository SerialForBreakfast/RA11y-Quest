# Changelog

All notable public API changes to ScreenAuditKit are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
ScreenAuditKit adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-05-03

First stable release. All public API from the initial development cycle is finalized and documented.

### Added — Contracts (Milestone A)

- `ScreenAuditContractSet` — top-level contract document with `schemaVersion`, screens, flows, asset provenance, and project metadata.
- `ScreenAuditContractError` — `.unsupportedSchemaVersion`, `.emptyRequiredField`.
- `ScreenAuditScreenContract` — per-screen contract: `devices`, `text`, `role`, `pedagogyRole`, `regions`, `baseline`, `assets`, `severityOverrides`.
- `ScreenAuditFlowContract` / `ScreenAuditFlowStep` — ordered step definitions with `required` and `requirePreviousStepPresent` flags.
- `ScreenAuditDeviceExpectation` — device label, family, pixel dimensions, and orientation.
- `ScreenAuditTextExpectations` — `required`, `optional`, and `forbidden` text rule sets.
- `ScreenAuditRegion` / `ScreenAuditRegionSet` — `protected`, `ignored`, and `critical` named pixel regions with normalized coordinate support.
- `ScreenAuditCoordinateSpace` — reference image dimensions for `ScreenAuditRegion.scaled(to:)`.
- `ScreenAuditBaselineExpectation` — reference PNG path and `maxMismatchRatio` threshold.
- `ScreenAuditAssetExpectations` / `ScreenAuditFallbackArtExpectation` — fallback-art confidence assertions with provenance linkage.
- `ScreenAuditAssetProvenanceSet` / `ScreenAuditAssetProvenance` — asset provenance records: `source`, `authoringStatus`, `sourceQuality`, `knownRisks`, `evidence`.
- `ScreenAuditAssetSource` — `.humanAuthored`, `.llmAuthored`, `.mockupCrop`, `.placeholder`, `.procedural`, `.unknown`.
- `ScreenAuditAssetAuthoringStatus` — `.final`, `.reviewNeeded`, `.temporary`, `.unknown`.
- `ScreenAuditAssetSourceQuality` — `.production`, `.review`, `.bootstrap`, `.low`, `.unknown`.
- `ScreenAuditDeviceFamily` — `.iPhone`, `.iPad`, `.mac`, `.tv`, `.vision`.
- `ScreenAuditOrientation` — `.portrait`, `.landscape`.
- `ScreenAuditScreenRole` — `.entry`, `.tutorial`, `.play`, `.success`, `.failure`, `.result`.
- `ScreenAuditPedagogyRole` — `.introduce`, `.reinforce`, `.practice`, `.test`, `.conclude`.
- `ScreenAuditSeverity` — `.info`, `.warning`, `.error`.

### Added — Evidence (Milestone B)

- `ScreenAuditOCRRecognizing` — injectable OCR protocol; conformers receive PNG data and a path, return `ScreenAuditOCRTranscript`.
- `ScreenAuditOCRTranscript` — `fullText` string and `recognitionStatus` (`.notRequested` / `.completed`).
- `ScreenAuditOCRRecognitionStatus` — enum distinguishing skipped vs. completed OCR runs.
- `ScreenAuditNoOpOCRRecognizer` — no-op conformer that marks the transcript as `.notRequested`.
- `ScreenAuditVisionOCRRecognizer` — Apple Vision `VNRecognizeTextRequest`-backed conformer (macOS).
- `ScreenAuditImageEvidenceExtractor` — extracts `ScreenAuditScreenshotEvidence` from PNG files or raw data: dimensions, alpha channel presence, OCR transcript.
- `ScreenAuditScreenshotEvidence` — `screenID`, `path`, `pixelWidth`, `pixelHeight`, `hasAlpha`, `ocrTranscript`.
- `ScreenAuditEvidenceError` — `.unreadableImage`, `.unsupportedImageType`, `.missingImageProperties`, `.ocrFailed`.
- `ScreenAuditOCROption` — `.none`, `.vision`; controls which recognizer the CLI and adapter scripts select.

### Added — Rules (Milestone B)

- `ScreenAuditRuleID` — all stable rule identifiers: `missingScreenshot`, `requiredTextMissing`, `forbiddenTextPresent`, `textRulesSkipped`, `dimensionMismatch`, `baselineDifferenceExceeded`, `suspiciousOpaqueBorder`, `renderedMatteRisk`, `checkerboardPatternRisk`, `lowConfidenceFallbackArt`, `flowUnknownStep`, `flowMissingRequiredStep`, `flowDuplicateStep`, `flowPreviousStepMissing`.
- `ScreenAuditFinding` — `ruleID`, `severity`, `confidence`, `message`, `evidence`.
- `ScreenAuditEvidenceReference` — `screenID`, `path`, `excerpt` linking a finding to its source.
- `ScreenAuditRuleEvaluator` — evaluates all deterministic rules against evidence, returns `[ScreenAuditFinding]`.

### Added — Validation (Milestone B)

- `ScreenAuditValidator` — orchestrates the full pipeline: evidence extraction → rule evaluation → report writing → overlay rendering.
- `ScreenAuditValidationResult` — `evidenceReport`, `findingsReport`, `flowReport`, `overlayPaths`.
- `ScreenAuditValidationError` — `.missingInput`, `.invalidInput`, `.reportWriteFailed`.

### Added — Reports (Milestone B)

- `ScreenAuditEvidenceReport` — JSON-serializable evidence summary with `reportVersion`, `projectName`, `screenshots`.
- `ScreenAuditFindingsReport` — JSON-serializable findings with `hasHardFailures` computed from `.error` severity.
- `ScreenAuditReportWriter` — writes evidence JSON, findings JSON, and Markdown summary; `markdownSummary` and `markdownFlowSummary` produce human-readable output.

### Added — CLI (Milestone B)

- `ScreenAuditCLI` — top-level CLI dispatcher; `run(arguments:)` returns a `ScreenAuditExitCode`.
- `ScreenAuditExitCode` — stable exit codes: `success=0`, `validationFailed=1`, `usageError=2`, `inputError=3`, `runtimeError=4`.
- `screenaudit validate` — `--screenshots`, `--contracts`, `--output`, `--ocr` flags.
- `screenaudit --version` — prints `ScreenAuditKit.version`.
- `screenaudit --help` — prints `ScreenAuditKit.helpText()`.

### Added — Visual Heuristics (Milestone D)

- `ScreenAuditTransparencyInspector` — opaque-border detection on alpha PNGs; `ScreenAuditOpaqueBorderInspection` result with `opaqueEdgeRatio` and `isSuspicious`.
- `ScreenAuditTransparencyError` — `.pixelDecodeFailed`.
- `ScreenAuditRenderedMatteInspector` — flat-matte block detection in named regions; `ScreenAuditRenderedMatteInspection` with `matteLikeRatio` and `isRisk`.
- `ScreenAuditRenderedMatteError` — `.pixelDecodeFailed`.
- `ScreenAuditCheckerboardInspector` — alternating-pattern artifact detection; `ScreenAuditCheckerboardInspection` with `alternatingRatio` and `isRisk`.
- `ScreenAuditCheckerboardError` — `.pixelDecodeFailed`.
- `ScreenAuditBaselineComparator` — per-pixel diff with ignored regions and configurable `maxMismatchRatio`; `ScreenAuditBaselineDiff` with `mismatchRatio`.
- `ScreenAuditBaselineError` — `.unreadableBaseline`, `.dimensionMismatch`, `.pixelDecodeFailed`.
- `ScreenAuditOverlayRenderer` — annotated PNG renderer; `ScreenAuditOverlayReport` with `findings`, `regions`, `overlayPath`.
- `ScreenAuditOverlayRegion` / `ScreenAuditOverlayRegionRole` — named overlay annotations with `.protected`, `.ignored`, `.critical`, `.screenshot` roles.
- `ScreenAuditOverlayRenderError` — `.pixelDecodeFailed`, `.pngWriteFailed`.

### Added — Flow Validation (Milestone E)

- `ScreenAuditFlowEvaluator` — ordered step evaluation against the observed screenshot set; returns `ScreenAuditFlowReport`.
- `ScreenAuditFlowReport` — `reportVersion`, `projectName`, `flows`; Markdown includes Mermaid graph.
- `ScreenAuditFlowResult` / `ScreenAuditFlowStepResult` — per-flow and per-step results with `status`.
- `ScreenAuditFlowStepStatus` — `.present`, `.missing`, `.unknown`.

### Added — Feature Walkthrough Export (Milestone F)

- `ScreenAuditFeatureWalkthroughArtifactExporter` — curates test artifacts into `Docs/FeatureWalkthrough/Artifacts/` and `Docs/FeatureWalkthrough/images/`; sanitizes machine paths.
- `ScreenAuditFeatureWalkthroughExportError` — `.missingTestArtifacts`, `.missingExpectedFile`, `.fileSystemError`.
- `screenaudit export-feature-walkthrough` — CLI command; accepts `--package-root` override.

---

## Exit Code Stability Guarantee

The following exit codes are **stable API** and will never change:

| Code | Constant | Meaning |
|------|----------|---------|
| `0` | `.success` | All rules passed |
| `1` | `.validationFailed` | One or more `.error`-severity findings |
| `2` | `.usageError` | Bad CLI invocation |
| `3` | `.inputError` | Missing or unreadable input files |
| `4` | `.runtimeError` | Unexpected failure during evaluation |
