# ScreenAuditKit Feature Walkthrough

Date: 2026-05-03  
Status: Living proof document

## Purpose

ScreenAuditKit is valuable when it proves release-relevant UI risks from actual PNG evidence. This walkthrough maps the strongest product capabilities to generated-image tests that run through the real validation pipeline and produce the same reports a reviewer would inspect.

The proof suite lives in `ScreenAuditFeatureWalkthroughTests`. The images are deterministic mechanical fixtures generated during tests under the package build directory; they are not production quest art.

## What This Proves

| Capability | Defect simulated | Proving test | Expected finding | Reviewer value |
|---|---|---|---|---|
| Required copy detection | A screenshot omits expected release copy | `testTextWalkthroughCatchesMissingAndForbiddenCopyAndSkipsWhenOCROff` | `requiredTextMissing` | Catches missing onboarding, product, or instructional text before screenshots ship. |
| Forbidden copy detection | A screenshot contains visible `DEBUG42` copy | `testTextWalkthroughCatchesMissingAndForbiddenCopyAndSkipsWhenOCROff` | `forbiddenTextPresent` | Prevents accidental debug, placeholder, or internal text from reaching docs or App Store assets. |
| No-OCR local pass | Text rules are declared but OCR is disabled | `testTextWalkthroughCatchesMissingAndForbiddenCopyAndSkipsWhenOCROff` | `textRulesSkipped` info | Keeps fast local validation honest without false hard failures. |
| Device profile validation | A screenshot has the wrong pixel size | `testDimensionWalkthroughCatchesWrongDeviceSize` | `dimensionMismatch` | Ensures committed screenshots came from the intended device profile. |
| Baseline drift | A stable content region changes while a volatile region is ignored | `testBaselineWalkthroughIgnoresVolatileRegionAndFlagsProtectedDrift` | `baselineDifferenceExceeded` | Focuses reviewers on meaningful visual drift instead of expected changing content. |
| Checkerboard artifact detection | A critical art region contains checkerboard transparency-bed pixels | `testVisualArtifactWalkthroughProducesFindingsAndOverlays` | `checkerboardPatternRisk` | Surfaces baked transparency artifacts that are easy to miss in dense UI screenshots. |
| Flat matte / missing art detection | A critical art region is a large flat gray block | `testVisualArtifactWalkthroughProducesFindingsAndOverlays` | `renderedMatteRisk` | Catches failed art rendering, placeholder rectangles, or bad crop output. |
| Opaque alpha border detection | An alpha-bearing PNG has opaque edges around transparent interior pixels | `testVisualArtifactWalkthroughProducesFindingsAndOverlays` | `suspiciousOpaqueBorder` | Flags export/alpha cleanup defects before they become visible UI artifacts. |
| Flow completeness | A later screenshot exists while a required predecessor is missing | `testFlowWalkthroughCatchesMissingRequiredPredecessor` | `missingScreenshot`, `flowMissingRequiredStep`, `flowPreviousStepMissing` | Validates screenshots as a coherent user journey, not just isolated images. |
| Clean happy path | A complete generated journey has valid dimensions and flow order | `testCleanHappyPathWalkthroughProducesNoFindings` | No findings | Proves the validator can distinguish clean evidence from defective evidence. |

## Why This Is Worth It

Traditional screenshot review is visual and manual: reviewers inspect large PNG sets and hope they notice copy regressions, broken art, device mismatches, and incomplete journey captures. ScreenAuditKit turns those risks into structured evidence:

- `summary.md` gives a review queue with severity, rule, impact, and next action.
- `findings.json` gives machine-readable gates for CI or release tooling.
- `flow-summary.md` gives product-sequence evidence for onboarding and quest journeys.
- Overlay PNGs and Markdown explain which visual regions were inspected.

The walkthrough tests prove those outputs are not mocked. They generate PNGs, validate them from disk, and assert the reports that a maintainer or stakeholder would actually use.

## Current Confidence Boundary

The suite intentionally uses simple deterministic images. That keeps failures actionable and avoids confusing image-generation artistry with validator behavior. The tests prove the mechanics and report value; RA11y’s committed screenshot audits prove the same engine can run against real app screenshots.

Future improvements can add richer fixture screenshots, but the current coverage already demonstrates the high-impact release risks: missing copy, debug copy, wrong dimensions, meaningful visual drift, transparency artifacts, matte placeholders, and incomplete user journeys.
