# Screen Audit Summary

- Project: Device Profile Walkthrough
- Findings: 1
- Hard failures (error): 1
- Warnings: 0
- Info: 0

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| error | dimensionMismatch | checkout | Screenshot dimensions were 844x390; expected one of: `fixture` 390x844. | The PNG dimensions do not match any declared device expectation, which can invalidate visual comparisons. | Verify the screenshot folder came from the expected simulator family and update device expectations only for intentional changes. | 844x390 |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| dimensionMismatch | The PNG dimensions do not match any declared device expectation, which can invalidate visual comparisons. | Verify the screenshot folder came from the expected simulator family and update device expectations only for intentional changes. |
