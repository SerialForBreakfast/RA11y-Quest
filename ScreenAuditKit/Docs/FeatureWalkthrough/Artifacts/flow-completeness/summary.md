# Screen Audit Summary

- Project: Flow Walkthrough
- Findings: 3
- Hard failures (error): 2
- Warnings: 1
- Info: 0

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).
- Ordered journey review: `flow-summary.md` (and machine-readable `flow.json`).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| error | missingScreenshot | permissions | Expected screenshot `02_Permissions.png` was not found. | A required screen did not produce a PNG, so docs, App Store assets, or flow validation may be stale. | Regenerate screenshots or update the contract only if the screen is intentionally removed. | 02_Permissions.png |
| error | flowMissingRequiredStep | permissions | Flow `releaseOnboarding` required step 2 screen `permissions` has no screenshot evidence. | A required flow step has no screenshot evidence in this audit run. | Regenerate the screenshot set or mark the step optional only if the flow no longer requires it. | flow=releaseOnboarding, step=2 |
| warning | flowPreviousStepMissing | ready | Flow `releaseOnboarding` step 3 screen `ready` is present but required predecessor `permissions` has no screenshot in this run. | A later flow step has a screenshot while an earlier required predecessor is missing, so the journey folder may be incomplete. | Regenerate the full flow screenshot set or clear `requirePreviousStepPresent` on the step if partial captures are expected. | missingPrevious=permissions |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| missingScreenshot | A required screen did not produce a PNG, so docs, App Store assets, or flow validation may be stale. | Regenerate screenshots or update the contract only if the screen is intentionally removed. |
| flowMissingRequiredStep | A required flow step has no screenshot evidence in this audit run. | Regenerate the screenshot set or mark the step optional only if the flow no longer requires it. |
| flowPreviousStepMissing | A later flow step has a screenshot while an earlier required predecessor is missing, so the journey folder may be incomplete. | Regenerate the full flow screenshot set or clear `requirePreviousStepPresent` on the step if partial captures are expected. |
