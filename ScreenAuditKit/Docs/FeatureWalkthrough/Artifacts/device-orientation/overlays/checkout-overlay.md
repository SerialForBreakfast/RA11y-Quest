# Screen Audit Overlay

- Screen: checkout
- Screenshot: <feature-walkthrough-test-output>/device-orientation-fail/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/device-orientation-fail/reports/overlays/checkout-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- error dimensionMismatch: Screenshot dimensions were 844x390; expected one of: `fixture` 390x844.
  Evidence: 844x390
  Review: Confirm this screenshot came from the expected device family before changing the contract.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| screenshot: screenshot | screenshot | x 0, y 0, width 844, height 390 | Whole-screen fallback used when a finding has no configured region. |
