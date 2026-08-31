# Executive-Grade ScreenAuditKit Walkthrough Plan

**Status (2026-08-21):** Historical plan. Walkthrough artifacts now live in
[`SerialForBreakfast/ScreenAuditKit`](https://github.com/SerialForBreakfast/ScreenAuditKit), not this monorepo.
Local `ScreenAuditKit/` paths below are obsolete.

## Summary
Upgrade the walkthrough from “algorithm proof” to “real UI failure proof.” The committed pass/fail images should look like plausible Apple-platform UI states, with defects that Product, QA, Design, and Engineering leaders immediately recognize: missing actions, clipped copy, wrong orientation, stale screenshots, broken artwork, debug text, and incomplete flows. The goal is for each scenario to be visually obvious to a human and mechanically proven by ScreenAuditKit.

## Key Changes
- Redesign walkthrough fixtures as polished native-style UI mock screenshots, generated deterministically in Swift/AppKit/CoreGraphics.
- Keep the images mechanical test fixtures, but make them resemble real iOS, iPadOS, macOS, and tvOS product screens.
- Commit curated pass/fail images and report excerpts under `ScreenAuditKit/Docs/FeatureWalkthrough/Artifacts/`.
- Make `ScreenAuditKit/Docs/FeatureWalkthrough/ScreenAuditKitFeatureWalkthrough.md` the polished executive-facing document.
- Keep tests as the source of proof: every displayed artifact must map to a passing `ScreenAuditFeatureWalkthroughTests` scenario.

## Showcase Scenarios
- **Missing critical action in an iOS alert**
  - Pass: alert includes `Cancel` and `Delete`.
  - Fail: destructive `Delete` exists, but `Cancel` is missing.
  - Proves `requiredTextMissing` catches missing recovery/escape actions.

- **Forbidden debug text in a production settings panel**
  - Pass: clean settings screen.
  - Fail: visible `DEBUG BUILD` or `TODO: wire API`.
  - Proves `forbiddenTextPresent` catches accidental internal copy.

- **Clipped onboarding copy in a fixed-height card**
  - Pass: two-line instruction fits.
  - Fail: second line is visibly cut off at the bottom.
  - Proves baseline/protected-region drift can catch layout regressions that plain text checks may miss.

- **Wrong device or orientation capture**
  - Pass: portrait iPhone-style screenshot at expected dimensions.
  - Fail: landscape/incorrect-size screenshot where bottom tab/menu content is missing.
  - Proves `dimensionMismatch` catches wrong screenshot profiles before release artifacts are accepted.

- **Volatile content ignored, stable UI protected**
  - Pass/fail pair changes only a clock/badge region and should pass.
  - Fail pair changes a stable primary CTA or title and should fail.
  - Proves baseline comparison can ignore expected volatility while still catching meaningful visual drift.

- **tvOS focus ring lost**
  - Pass: focused tile has a bright focus ring and label.
  - Fail: same tile appears unfocused or focus styling is missing.
  - Proves visual checks can protect remote-navigation affordances.

- **macOS toolbar item missing**
  - Pass: window toolbar includes Search, Share, and Help.
  - Fail: Help button is absent or clipped after resizing.
  - Proves screenshots can gate desktop chrome regressions.

- **Broken artwork / flat placeholder**
  - Pass: critical hero/art region has varied color and detail.
  - Fail: same region is a large flat gray placeholder block.
  - Proves `renderedMatteRisk` catches failed asset rendering or placeholder art.

- **Checkerboard transparency artifact**
  - Pass: illustration appears on a clean background.
  - Fail: checkerboard pattern is visible behind the asset.
  - Proves `checkerboardPatternRisk` catches baked transparency-bed issues.

- **Opaque alpha border around transparent asset**
  - Pass: transparent asset has clean edges.
  - Fail: asset has an opaque rectangular matte around transparent interior pixels.
  - Proves `suspiciousOpaqueBorder` catches export/alpha cleanup defects.

- **Incomplete product journey**
  - Pass: ordered onboarding flow includes Welcome, Permissions, Ready.
  - Fail: Ready exists but Permissions is missing.
  - Proves flow validation catches incomplete narrative capture, not just isolated PNG issues.

- **Clean happy path**
  - Pass: representative generated screenshot set has expected dimensions, copy, visual regions, and flow order.
  - Proves ScreenAuditKit can distinguish healthy evidence from defective evidence.

## Fixture Design Standards
- Each image should read as a believable Apple-platform UI, not a blank canvas with one token.
- Use consistent visual language: status bars, nav bars, cards, toolbars, focus rings, tab bars, modal sheets, and buttons.
- Make failures visually obvious:
  - Use callout-friendly layout, but do not draw artificial arrows into the screenshot unless that artifact is itself part of the tested UI.
  - Keep pass/fail pairs compositionally similar so the defect is the clear difference.
  - Prefer realistic defect names in text: `Cancel`, `Continue`, `Privacy`, `Help`, `DEBUG BUILD`, `TODO`.
- Use small but legible generated dimensions to keep tests fast while preserving UI credibility.
- Avoid photorealistic or authored quest art; fixtures are deterministic UI diagrams.

## Walkthrough Document
- Replace the top-level proof table with concise executive narrative sections.
- Each scenario section should include:
  - one-sentence product risk,
  - pass/fail image pair table,
  - expected rule finding,
  - short quoted excerpt from `summary.md` or `findings.json`,
  - proving test method,
  - plain-language business value.
- Start with a short executive framing:
  - “ScreenAuditKit turns screenshot review into structured, repeatable evidence.”
  - “It catches copy, layout, visual artifact, asset, device-profile, and flow regressions before release.”
- End with a “What this changes operationally” section:
  - fewer manual screenshot review misses,
  - clearer CI gates,
  - better QA/design handoff,
  - portable proof artifacts for app teams.

## Test and Artifact Plan
- Extend `ScreenAuditFeatureWalkthroughTests` to generate polished platform-style pass/fail fixtures.
- Add positive and negative fixtures for every scenario where the contrast matters.
- Assert the generated reports, not just rule internals:
  - `summary.md` contains the rule and reviewer guidance,
  - `findings.json` contains expected rule/severity/evidence,
  - overlays exist for visual findings,
  - `flow-summary.md` marks missing/present steps correctly.
- Add `ScreenAuditKit/Docs/FeatureWalkthrough/refresh_artifacts.sh` to copy curated generated outputs from `.build/test-artifacts/feature-walkthrough/` into committed docs artifacts.
- Commit only curated docs artifacts, not raw `.build` paths.

## Validation Plan
- Run:
  - `swift test --package-path ScreenAuditKit`
  - `bash ScreenAuditKit/Docs/FeatureWalkthrough/refresh_artifacts.sh`
  - `swift test --package-path ScreenAuditKit`
  - `bash utility/screenaudit_doctor.sh`
  - `bash utility/validate_screen_audit.sh --ocr none`
  - `bash utility/validate_screen_audit.sh --ocr vision`
  - `git diff --check`
- Manually inspect the committed pass/fail image pairs for readability before declaring complete.
- Confirm every walkthrough image appears from `ScreenAuditKit/Docs/FeatureWalkthrough/Artifacts/`, not `.build`.

## Assumptions
- The walkthrough is meant for senior/executive product and engineering stakeholders, so clarity and credibility matter more than minimal fixture size.
- The images remain deterministic generated UI fixtures, not production quest art.
- The tests should prove real-world Apple-platform failure modes across iOS, tvOS, and macOS-style UI patterns without adding platform app targets.
