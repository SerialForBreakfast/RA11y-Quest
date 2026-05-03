# Screen Audit Overlay

- Screen: onboarding
- Screenshot: <feature-walkthrough-test-output>/baseline-clipped-fail/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/baseline-clipped-fail/reports/overlays/onboarding-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- warning baselineDifferenceExceeded: Baseline mismatch ratio 0.0659 exceeded allowed ratio 0.0100.
  Evidence: 21529/326472 pixels
  Review: Compare highlighted stable regions against the baseline and decide whether the visual drift is intentional.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| ignored: status-clock | ignored | x 18, y 14, width 96, height 28 | Volatile content excluded from broad visual comparisons. |
| protected: instruction-card | protected | x 34, y 180, width 322, height 390 | Stable visual content that should not drift unexpectedly. |
