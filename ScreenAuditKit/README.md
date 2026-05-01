# ScreenAuditKit

`ScreenAuditKit` is a local Swift Package for deterministic screenshot validation.
RA11y is the first consumer, but the package boundary is intentionally generic:
screenshot folders and validation contracts are inputs, and reports plus exit
codes are outputs.

Products:

- `ScreenAuditKit`: library target for contracts, evidence, rules, and reports.
- `screenaudit`: command-line target for local and CI/CD use.

Current status: local package with versioned contract decoding, PNG metadata
evidence extraction, injectable OCR boundary, deterministic text/dimension
rules, baseline comparison, visual heuristic inspectors, overlay report
generation, asset provenance warnings, and ordered flow validation.

The package deliberately stays app-agnostic. RA11y supplies screenshot contracts,
critical regions, and asset provenance data from its iOS UI test bundle.

```sh
swift test --package-path ScreenAuditKit
swift run --package-path ScreenAuditKit screenaudit --help
```

RA11y adapter command:

```sh
bash utility/validate_screen_audit.sh
```

Fastlane adapter:

```sh
bundle exec fastlane ios screen_audit
```

Reports are written under `build_results/screen-audit/` by device folder:

- `evidence.json`: collected screenshot facts
- `findings.json`: machine-readable findings
- `summary.md`: reviewer summary
- `flow.json`: ordered flow validation facts
- `flow-summary.md`: reviewer summary for screenshot journeys
- `overlays/*.png`: annotated screenshots for findings
- `overlays/*.md` and `overlays/*.json`: explanation sidecars for each overlay

Current RA11y UI/design inputs:

- `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json`
- `RA11y-iOS/RA11y-iOSUITests/ScreenAuditAssetProvenance.json`
- `memlog/designRefactorTasks.md`
- `memlog/research/ScreenAuditKit-Workstream.md`
