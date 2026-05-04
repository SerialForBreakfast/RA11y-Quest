# ScreenAuditKit — Tasks

## Status Legend

- `[x]` Done
- `[~]` In progress / partial
- `[ ]` Not started

Full architecture and workstream rationale: `memlog/research/ScreenAuditKit-Workstream.md`  
(that file stays in the monorepo; this file travels with the package)

---

## Milestone A: Package Skeleton + Contract Core ✅

- [x] Local SPM package created (`Package.swift`, library + CLI targets)
- [x] Versioned JSON contract schema (`schemaVersion`, device expectations, regions, baselines, assets)
- [x] `ScreenAuditContracts.swift` — full decode + validation with `unsupportedSchemaVersion` guard
- [x] Fixture JSON files for schema tests (`valid-contracts.json`, `unsupported-schema-contracts.json`, etc.)
- [x] CLI `screenaudit --help` and `--version`

## Milestone B: Deterministic Validation MVP ✅

- [x] PNG metadata extraction (dimensions, alpha channel, ImageIO)
- [x] Injectable OCR protocol (`ScreenAuditOCRRecognizing`) + Vision implementation + no-op
- [x] Required / forbidden / optional text rules
- [x] Dimension mismatch rule
- [x] JSON evidence report + JSON findings report
- [x] Markdown summary report
- [x] `screenaudit validate` CLI command with all flags and stable exit codes
- [x] `ScreenAuditKitTests` covering contracts, evidence, rules, reports

## Milestone C: RA11y Adapter ✅

- [x] `utility/validate_screen_audit.sh` — shell adapter for monorepo fastlane integration
- [x] `utility/screenaudit_doctor.sh` — pre-flight contract alignment checker
- [x] RA11y fastlane lanes (`screenshots`, `screen_audit`) wired to adapter scripts
- [x] RA11y `ScreenAuditContracts.json` for all committed screenshot scenes

## Milestone D: Visual Heuristics ✅

- [x] `ScreenAuditTransparencyInspector` — opaque-border detection on alpha PNGs
- [x] `ScreenAuditRenderedMatteInspector` — flat-matte block detection in critical regions
- [x] `ScreenAuditCheckerboardInspector` — alternating-pattern artifact detection
- [x] `ScreenAuditBaselineComparator` — per-pixel diff with ignored regions and thresholds
- [x] Overlay PNG renderer — annotated screenshots showing rule findings
- [x] Asset provenance contract fields (`assetProvenancePath`, confidence assertions)
- [x] Tests: `ScreenAuditTransparencyTests`, `ScreenAuditRenderedMatteTests`, `ScreenAuditCheckerboardTests`, `ScreenAuditBaselineTests`

## Milestone E: Flow Validation ✅

- [x] `ScreenAuditFlowValidation.swift` — ordered step evaluation, missing/duplicate detection
- [x] Flow findings: `flowUnknownStep`, `flowMissingRequiredStep`, `flowDuplicateStep`, `flowPreviousStepMissing`
- [x] Flow Mermaid graph in Markdown report
- [x] `ScreenAuditFlowTests` + `ScreenAuditValidatorFlowTests`
- [x] RA11y quest flow contracts (Home, VoiceOver, Enchanter, Dungeon, Banishment)

## Milestone F: Feature Walkthrough Export ✅

- [x] `ScreenAuditFeatureWalkthroughArtifactExporter` — Swift implementation of artifact curation
- [x] `screenaudit export-feature-walkthrough [--package-root <dir>]` CLI command
- [x] `Utility/export_feature_walkthrough.sh` — thin shell wrapper
- [x] `Docs/FeatureWalkthrough/Artifacts/` — 9 curated scenarios with PNGs, reports, overlays
- [x] `Docs/FeatureWalkthrough/images/` — flattened PNG set for Markdown embedding
- [x] Path sanitization (machine paths replaced with placeholder before committing)
- [x] Tests: `testExportFeatureWalkthroughFailsWhenTestArtifactsMissing`, help text assertion
- [x] Removed `refresh_artifacts.sh` (logic is now in Swift)
- [ ] **Commit** all uncommitted feature walkthrough changes

## Milestone G: Pedagogy Validation [~]

- [~] Generic pedagogy roles defined in contract (`pedagogyRole`: introduce, reinforce, practice, test, conclude)
- [ ] Deterministic pedagogy rules: required lesson phrase in introduction, forbidden tutorial wording in trial screens, result copy confirms learned action
- [ ] RA11y-specific pedagogy contracts for each quest arc
- [ ] `ScreenAuditPedagogyTests`

## Milestone H: CI/CD Hardening [ ]

- [ ] JUnit XML output (`--format junit`)
- [ ] SARIF output for GitHub code scanning (`--format sarif`)
- [ ] PR comment artifacts (Markdown summary posted as CI comment)
- [ ] Baseline management commands (`screenaudit baseline accept`, `screenaudit baseline diff`)
- [ ] Multi-locale support in contracts (`locales[]` field)
- [ ] Dynamic Type variant contracts

## Milestone I: Extraction Readiness [~]

- [x] No RA11y-specific code in `Sources/ScreenAuditKit/`
- [x] `AGENTS.md` inside package
- [x] `Tasks.md` inside package
- [x] `README.md` includes standalone-repo instructions
- [x] `LICENSE` file added (MIT)
- [x] Package version bumped from `0.1.0-local` to `1.0.0`
- [x] `CHANGELOG.md` created with all public API changes from initial development
- [x] Public API audit: all public symbols have doc comments (verified 2026-05-03)
- [x] Monorepo adapter scripts updated to reference external package path pattern
- [ ] External SPM URL decided (GitHub org / repo name)

---

## Open Decisions

| Decision | Status | Options |
|---|---|---|
| License | **Decided: MIT** | MIT |
| Package name (final) | Likely `ScreenAuditKit` | No change proposed |
| External repo URL | Open | `github.com/[org]/ScreenAuditKit` |
| Baseline image storage | Open | In-repo vs. artifact store |
| JUnit / SARIF timing | Open | Milestone H |
| Pedagogy checklist spec | Partial | Milestone G |
