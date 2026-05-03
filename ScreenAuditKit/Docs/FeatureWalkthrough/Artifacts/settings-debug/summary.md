# Screen Audit Summary

- Project: Settings Walkthrough
- Findings: 2
- Hard failures (error): 2
- Warnings: 0
- Info: 0

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| error | forbiddenTextPresent | settings | Forbidden text `DEBUG BUILD` was found. | Debug, placeholder, or otherwise forbidden copy appears in the captured UI. | Remove the forbidden copy from the UI or narrow the contract if it is intentionally visible. | DEBUG BUILD |
| error | forbiddenTextPresent | settings | Forbidden text `TODO` was found. | Debug, placeholder, or otherwise forbidden copy appears in the captured UI. | Remove the forbidden copy from the UI or narrow the contract if it is intentionally visible. | TODO |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| forbiddenTextPresent | Debug, placeholder, or otherwise forbidden copy appears in the captured UI. | Remove the forbidden copy from the UI or narrow the contract if it is intentionally visible. |
