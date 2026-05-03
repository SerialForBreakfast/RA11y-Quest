# Screen Audit Overlay

- Screen: libraryWindow
- Screenshot: <feature-walkthrough-test-output>/mac-toolbar-fail/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/mac-toolbar-fail/reports/overlays/libraryWindow-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- error requiredTextMissing: Required text `Help` was not found.
  Evidence: Project Library
Search
Share
  Review: Check whether the expected copy is missing, clipped, localized differently, or absent from OCR evidence.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| screenshot: screenshot | screenshot | x 0, y 0, width 900, height 560 | Whole-screen fallback used when a finding has no configured region. |
