# Screen Audit Overlay

- Screen: deleteAlert
- Screenshot: <feature-walkthrough-test-output>/ios-alert-fail/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/ios-alert-fail/reports/overlays/deleteAlert-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- error requiredTextMissing: Required text `Cancel` was not found.
  Evidence: 10:41
Files
Delete saved project?
This action removes the local copy fr....
Delete
  Review: Check whether the expected copy is missing, clipped, localized differently, or absent from OCR evidence.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| screenshot: screenshot | screenshot | x 0, y 0, width 390, height 844 | Whole-screen fallback used when a finding has no configured region. |
