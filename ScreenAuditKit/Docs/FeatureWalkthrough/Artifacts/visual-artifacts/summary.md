# Screen Audit Summary

- Project: Visual Artifact Walkthrough
- Findings: 3
- Hard failures (error): 0
- Warnings: 3
- Info: 0

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| warning | renderedMatteRisk | matte | Critical region `hero-art` contains a large flat white, black, or gray block that may indicate a rendered matte artifact. | A critical visual region appears too flat or matte-like for authored art. | Inspect the highlighted critical region for missing art, flat placeholder rendering, or an incorrectly cropped asset. | 88112/88184 matte-like pixels |
| warning | checkerboardPatternRisk | checker | Region `hero-art` contains an alternating checkerboard-like pattern that may indicate a rendered transparency artifact. | A critical visual region resembles a checkerboard transparency artifact. | Inspect the highlighted critical region for checkerboard transparency showing through the final UI. | 1260/1260 alternating cell groups |
| warning | suspiciousOpaqueBorder | alpha | PNG has fully opaque edges around transparent interior pixels, which can indicate a rectangular matte or bad alpha cleanup. | A transparent asset may have exported with an opaque rectangular matte around it. | Inspect the source PNG alpha/export settings and re-ingest the asset if the matte is real. | 2464/2464 edge pixels opaque; 286032 transparent interior pixels |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| renderedMatteRisk | A critical visual region appears too flat or matte-like for authored art. | Inspect the highlighted critical region for missing art, flat placeholder rendering, or an incorrectly cropped asset. |
| checkerboardPatternRisk | A critical visual region resembles a checkerboard transparency artifact. | Inspect the highlighted critical region for checkerboard transparency showing through the final UI. |
| suspiciousOpaqueBorder | A transparent asset may have exported with an opaque rectangular matte around it. | Inspect the source PNG alpha/export settings and re-ingest the asset if the matte is real. |
