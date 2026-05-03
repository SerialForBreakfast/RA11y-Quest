# Screen Audit Overlay

- Screen: checker
- Screenshot: <feature-walkthrough-test-output>/visual-artifacts-fail/screenshots/checker.png
- Overlay: <feature-walkthrough-test-output>/visual-artifacts-fail/reports/overlays/checker-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- warning checkerboardPatternRisk: Region `hero-art` contains an alternating checkerboard-like pattern that may indicate a rendered transparency artifact.
  Evidence: 1260/1260 alternating cell groups
  Review: Inspect the red critical region for checkerboard transparency showing through the final render.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| critical: hero-art | critical | x 44, y 176, width 302, height 292 | High-value visual content checked for obvious asset or rendering defects. |
