# Screenshot and screen audit golden path

Date: 2026-05-01  
Status: Operational guide (RA11y + ScreenAuditKit)

## Purpose

One entry point for contributors: how to keep **Fastlane capture**, **route catalog**, **scene boot paths**, **UI tests**, and **ScreenAuditKit contracts** aligned, and how to run checks locally without guessing paths or environment variables.

Authoritative schema and rule details live in the external package:
[ScreenAuditKit README](https://github.com/SerialForBreakfast/ScreenAuditKit). This document is the **RA11y workflow** layer (capture, catalog, contracts, Fastlane).

---

## Quick checks (run in order)

1. **Screenshot automation contract** (Fastlane allowlist, catalog, scenes, UI tests):

   ```bash
   bash utility/validate_screenshot_contract.sh
   ```

2. **Screen audit contract vs route catalog + flow IDs** (no PNGs required):

   ```bash
   bash utility/screenaudit_doctor.sh
   ```

3. **Full ScreenAuditKit validation** (requires `docs/screenshots/en-US/<device>/*.png`):

   ```bash
   # Fast metadata-only pass (text rules are skipped with info findings)
   bash utility/validate_screen_audit.sh --ocr none

   # Match CI / text rules (`text.required`, `text.forbidden`)
   bash utility/validate_screen_audit.sh --ocr vision
   ```

   Equivalent profile knob:

   ```bash
   RA11Y_SCREEN_AUDIT_PROFILE=ci bash utility/validate_screen_audit.sh
   ```

   `RA11Y_SCREEN_AUDIT_PROFILE=ci` implies Vision OCR when `--ocr` is not passed (same behavior Fastlane uses for the audit gate).

Optional: combine steps 1–2 and, when PNGs exist, step 3:

```bash
bash utility/screenaudit_doctor.sh --with-audit
```

`--with-audit` runs `validate_screen_audit.sh` with `--ocr none` for speed unless you export `RA11Y_SCREEN_AUDIT_OCR=vision` first. In no-OCR mode, `text.required` and `text.forbidden` rules are reported as skipped info findings rather than hard failures.

---

## Surfaces to update when you add or change a screenshoted screen

| Surface | File | What to change |
|--------|------|-----------------|
| Scene boot | `RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift` | `case` + `"-screenshotScene"` raw value |
| Capture test | `RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift` | Test method, waits on root anchor |
| Coverage table | `RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md` | New table row (file basename, method, scene, anchor) |
| Fastlane allowlist | `fastlane/Fastfile` | `UI_TEST_IDS` includes `…/testScreenshots_…` |
| Pixel/text/flow rules | `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json` | `screens[]`, optional `flows[]`, device sizes |
| Asset risk metadata | `RA11y-iOS/RA11y-iOSUITests/ScreenAuditAssetProvenance.json` | When using provenance rules for that screen |

The first four rows mirror [AGENTS.md](../../AGENTS.md) **Screenshot Automation Contract**. Screen audit JSON is the **fifth** layer for anything ScreenAuditKit enforces beyond “did Fastlane extract the right files?”.

---

## Adoption levels (progressive)

Use these to avoid boiling the ocean.

| Level | You enable | ScreenAuditKit enforces |
|-------|------------|-------------------------|
| **A** | Route catalog + Fastlane + contracts with dimensions (and optional minimal `text`) | PNG presence, size, flow structure when `flows` are declared; text rules appear as skipped info when OCR is off |
| **B** | `--ocr vision` locally or in CI | `text.required` / `text.forbidden` via Vision |
| **C** | Regions, baselines, provenance | Visual heuristics, pixel diff gates, fallback-art confidence |

Start at A for new routes; add B when copy checks are stable; add C only where flakes are acceptable.

---

## Fastlane vs local

| Goal | Command |
|------|---------|
| Capture + audit fresh PNGs | `bundle exec fastlane ios screenshots` |
| Audit committed `docs/screenshots` only | `bundle exec fastlane ios screen_audit` |

Both use Vision OCR for the audit step (`--ocr vision` on the shell adapter).

---

## Optional: stub JSON for new catalog rows

If `screenaudit_doctor.sh` reports catalog files missing from `ScreenAuditContracts.json`, you can emit minimal `screens[]` fragments to paste (ids and filenames come from the catalog):

```bash
bash utility/screenaudit_doctor.sh --emit-stub
```

You must still fill in `devices`, `text`, and any regions yourself; stubs are scaffolding only.

---

## Related docs

- [ScreenAuditKit README](https://github.com/SerialForBreakfast/ScreenAuditKit) — CLI, contract schema, reports, roadmap
- [ScreenAuditKit-Workstream.md](./ScreenAuditKit-Workstream.md) — historical SAK milestones (package now extracted)
- [ADR-0005-Native-Screenshot-Flow-And-Pedagogy-Validation.md](./ADR-0005-Native-Screenshot-Flow-And-Pedagogy-Validation.md) — original rationale

Cursor / VS Code: see `.vscode/tasks.json` tasks **Screenshot contract check**, **Screen audit doctor**, **Screen audit (committed screenshots)**.
