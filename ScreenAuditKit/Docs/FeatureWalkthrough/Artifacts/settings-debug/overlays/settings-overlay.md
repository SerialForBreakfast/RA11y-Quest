# Screen Audit Overlay

- Screen: settings
- Screenshot: <feature-walkthrough-test-output>/settings-debug-fail/screenshots/screen.png
- Overlay: <feature-walkthrough-test-output>/settings-debug-fail/reports/overlays/settings-overlay.png

## How to Read This Overlay

The PNG draws only the regions ScreenAuditKit reviewed for this failed screen. A rectangle is not automatically the failing pixel; it is the inspection area tied to the findings below.

| Color | Role | Meaning |
|---|---|---|
| Red | critical / screenshot | High-signal review area for missing art, matte blocks, checkerboard artifacts, or a whole-screen fallback when no region is configured. |
| Blue | protected | Region expected to remain visually stable during baseline comparison. |
| Amber | ignored | Region intentionally ignored for broad baseline comparison, usually because it contains volatile content. |

## Findings

- error forbiddenTextPresent: Forbidden text `DEBUG BUILD` was found.
  Evidence: DEBUG BUILD
  Review: Look for debug or placeholder text in the screenshot and remove it if it is not intentional.
- error forbiddenTextPresent: Forbidden text `TODO` was found.
  Evidence: TODO
  Review: Look for debug or placeholder text in the screenshot and remove it if it is not intentional.

## Regions

| Label | Role | Rectangle | Why shown |
|---|---|---|---|
| screenshot: screenshot | screenshot | x 0, y 0, width 390, height 844 | Whole-screen fallback used when a finding has no configured region. |
