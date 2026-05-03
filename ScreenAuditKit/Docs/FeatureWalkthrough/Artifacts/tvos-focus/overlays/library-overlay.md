# Screen Audit Overlay

- Screen: library
- Screenshot: <feature-walkthrough-test-output>/tvos-focus-fail/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/tvos-focus-fail/reports/overlays/library-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- warning baselineDifferenceExceeded: Baseline mismatch ratio 0.0157 exceeded allowed ratio 0.0100.
  Evidence: 8124/518400 pixels
  Review: Compare highlighted stable regions against the baseline and decide whether the visual drift is intentional.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| protected: focused-tile | protected | x 86, y 172, width 262, height 186 | Stable visual content that should not drift unexpectedly. |
