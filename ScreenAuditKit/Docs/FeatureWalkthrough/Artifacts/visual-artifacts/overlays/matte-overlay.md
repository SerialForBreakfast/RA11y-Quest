# Screen Audit Overlay

- Screen: matte
- Screenshot: <feature-walkthrough-test-output>/visual-artifacts-fail/screenshots/matte.png
- Overlay: <feature-walkthrough-test-output>/visual-artifacts-fail/reports/overlays/matte-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- warning renderedMatteRisk: Critical region `hero-art` contains a large flat white, black, or gray block that may indicate a rendered matte artifact.
  Evidence: 88112/88184 matte-like pixels
  Review: Inspect the red critical region for flat placeholder rendering or missing authored art.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| critical: hero-art | critical | x 44, y 176, width 302, height 292 | High-value visual content checked for obvious asset or rendering defects. |
