# Screen Audit Overlay

- Screen: alpha
- Screenshot: <feature-walkthrough-test-output>/visual-artifacts-fail/screenshots/alpha.png
- Overlay: <feature-walkthrough-test-output>/visual-artifacts-fail/reports/overlays/alpha-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- warning suspiciousOpaqueBorder: PNG has fully opaque edges around transparent interior pixels, which can indicate a rectangular matte or bad alpha cleanup.
  Evidence: 2464/2464 edge pixels opaque; 286032 transparent interior pixels
  Review: Inspect the asset edge and alpha export; the highlighted region may contain an opaque matte.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| screenshot: screenshot | screenshot | x 0, y 0, width 390, height 844 | Whole-screen fallback used when a finding has no configured region. |
