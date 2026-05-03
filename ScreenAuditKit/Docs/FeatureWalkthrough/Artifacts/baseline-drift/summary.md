# Screen Audit Summary

- Project: Baseline Walkthrough
- Findings: 1
- Hard failures (error): 0
- Warnings: 1
- Info: 0

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| warning | baselineDifferenceExceeded | onboarding | Baseline mismatch ratio 0.0659 exceeded allowed ratio 0.0100. | The screenshot changed more than the allowed baseline threshold outside ignored regions. | Compare the overlay and baseline; accept a new baseline only after confirming the visual change is intentional. | 21529/326472 pixels |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| baselineDifferenceExceeded | The screenshot changed more than the allowed baseline threshold outside ignored regions. | Compare the overlay and baseline; accept a new baseline only after confirming the visual change is intentional. |
