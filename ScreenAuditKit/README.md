# ScreenAuditKit

`ScreenAuditKit` is a local Swift Package for deterministic screenshot validation.
RA11y is the first consumer, but the package boundary is intentionally generic:
screenshot folders and validation contracts are inputs, and reports plus exit
codes are outputs.

Initial products:

- `ScreenAuditKit`: library target for contracts, evidence, rules, and reports.
- `screenaudit`: command-line target for local and CI/CD use.

Current status: local package with versioned contract decoding, PNG metadata
evidence extraction, injectable OCR boundary, and initial deterministic text /
dimension rules. CLI validation and report writing will land in later workstream
tasks.

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
