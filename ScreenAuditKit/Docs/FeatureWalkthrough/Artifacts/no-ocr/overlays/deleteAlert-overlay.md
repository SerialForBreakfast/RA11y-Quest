# Screen Audit Overlay

- Screen: deleteAlert
- Screenshot: <feature-walkthrough-test-output>/no-ocr-skip/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/no-ocr-skip/reports/overlays/deleteAlert-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- info textRulesSkipped: Skipped 1 required and 1 forbidden text rule(s) because OCR was not requested.
  Evidence: required=Cancel | forbidden=DEBUG BUILD
  Review: No overlay can prove skipped OCR text rules; rerun with `--ocr vision` to inspect copy.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| screenshot: screenshot | screenshot | x 0, y 0, width 390, height 844 | Whole-screen fallback used when a finding has no configured region. |
