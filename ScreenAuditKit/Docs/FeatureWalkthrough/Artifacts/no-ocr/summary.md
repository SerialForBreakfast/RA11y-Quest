# Screen Audit Summary

- Project: No OCR Walkthrough
- Findings: 1
- Hard failures (error): 0
- Warnings: 0
- Info: 1

## Where to look next

- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).

## Review Queue

| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |
|---|---|---|---|---|---|---|
| info | textRulesSkipped | deleteAlert | Skipped 1 required and 1 forbidden text rule(s) because OCR was not requested. | Text rules were declared, but this audit did not request OCR, so copy was not checked. | Run the audit again with `--ocr vision` when text required/forbidden rules need enforcement. | required=Cancel \| forbidden=DEBUG BUILD |

## Rule Guide

| Rule | What ScreenAuditKit examined | Typical fix |
|---|---|---|
| textRulesSkipped | Text rules were declared, but this audit did not request OCR, so copy was not checked. | Run the audit again with `--ocr vision` when text required/forbidden rules need enforcement. |
