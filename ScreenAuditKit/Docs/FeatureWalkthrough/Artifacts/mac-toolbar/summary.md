# Screen Audit Summary

- Project: macOS Toolbar Walkthrough
- Findings: 1
- Hard failures (error): 1
- Warnings: 0
- Info: 0

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| error | requiredTextMissing | libraryWindow | Required text `Help` was not found. | Expected instructional or identifying copy was not detected in the screenshot evidence. | Open the referenced PNG and confirm whether the copy is absent, clipped, localized differently, or missing from OCR. | Project Library Search Share |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| requiredTextMissing | Expected instructional or identifying copy was not detected in the screenshot evidence. | Open the referenced PNG and confirm whether the copy is absent, clipped, localized differently, or missing from OCR. |
