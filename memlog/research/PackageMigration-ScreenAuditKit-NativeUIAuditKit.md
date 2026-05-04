# Package Migration Strategy: ScreenAuditKit & NativeUIAuditKit

**Status:** Planning  
**As of:** 2026-05-03  
**Audience:** RA11y maintainers performing or preparing the monorepo → standalone repo split

---

## 1. Overview

Both Swift packages currently live inside the RA11y monorepo for development velocity. This
document defines the migration path to extract each package into its own GitHub repository while
keeping the RA11y fastlane integration working, contracts in place, and CI unbroken.

**Packages to migrate:**

| Package | Current path | Target state |
|---------|-------------|-------------|
| `ScreenAuditKit` | `ScreenAuditKit/` | Standalone repo, added as SPM dependency |
| `NativeUIAuditKit` | `NativeUIAuditKit/` | Standalone repo (after Phase 6 milestone — model ready) |

**Do not rush NativeUIAuditKit.** It is a research scaffold (Phase 0). Extract it only after the
Phase 6 CoreML model milestone produces a working detector. ScreenAuditKit is production-ready and
can be extracted independently at any time.

---

## 2. Pre-Migration Checklist

Complete every item before touching any repository structure.

### ScreenAuditKit

- [ ] Commit all uncommitted changes (feature walkthrough module, test updates, docs)
- [ ] `swift build` passes with zero errors and zero warnings
- [ ] `swift test` passes all 75+ tests
- [ ] `Tasks.md` Milestone F marked complete (feature walkthrough export committed)
- [ ] `AGENTS.md` inside `ScreenAuditKit/` reviewed and accurate
- [ ] `README.md` has a "Standalone repo" section with build and integration instructions
- [ ] `LICENSE` file exists at `ScreenAuditKit/LICENSE` (MIT or Apache 2.0 — decide first)
- [ ] Package version bumped from `0.1.0-local` to `1.0.0` in `ScreenAuditKit.swift`
- [ ] All `public` symbols have doc comments
- [ ] No hardcoded absolute paths in any committed file in `Sources/` or `Docs/`
- [ ] `utility/validate_screen_audit.sh` updated to support external-package path pattern
- [ ] `utility/screenaudit_doctor.sh` updated with migration notes

### NativeUIAuditKit

- [ ] Phase 6 CoreML detector milestone complete (mAP@0.5 ≥ 0.70 on withheld-template test)
- [ ] `NativeUIAuditKitModels` package structure defined and `.mlpackage` trained
- [ ] `swift build` and `swift test` pass
- [ ] `AGENTS.md` inside `NativeUIAuditKit/` reviewed and accurate
- [ ] `README.md` has integration instructions for projects that are not RA11y
- [ ] `LICENSE` file exists
- [ ] No RA11y-specific code in `Sources/`

---

## 3. Migration Steps — ScreenAuditKit

### Step 1: Create the standalone GitHub repository

```bash
# On GitHub: create a new empty repo (e.g. github.com/[org]/ScreenAuditKit)
# Initialize with no README, no .gitignore — we bring our own

git clone https://github.com/[org]/ScreenAuditKit.git /tmp/ScreenAuditKit-standalone
```

### Step 2: Copy the package directory

```bash
# From the monorepo root
cp -r ScreenAuditKit/. /tmp/ScreenAuditKit-standalone/

# Verify no monorepo-specific files leaked
ls /tmp/ScreenAuditKit-standalone/
# Expected: AGENTS.md  Docs/  Package.swift  README.md  Sources/  Tasks.md  Tests/  Utility/  .gitignore
```

### Step 3: Verify the package builds standalone

```bash
cd /tmp/ScreenAuditKit-standalone
swift build    # must succeed with no reference to monorepo paths
swift test     # must pass all tests
```

### Step 4: Push to the new repository

```bash
cd /tmp/ScreenAuditKit-standalone
git add -A
git commit -m "Initial extraction from RA11y monorepo (v1.0.0)"
git tag 1.0.0
git push origin main --tags
```

### Step 5: Add as SPM dependency in RA11y

In `RA11y.xcworkspace`, open `Package.swift` or use Xcode's package manager UI:

```swift
// If RA11y has a Package.swift (or add via Xcode file → Add Package)
.package(url: "https://github.com/[org]/ScreenAuditKit.git", from: "1.0.0")
```

### Step 6: Update the monorepo adapter scripts

The adapter scripts currently use `--package-path "$ROOT/ScreenAuditKit"` to run the CLI.
After extraction, the CLI is no longer a local package — update the invocation pattern:

**Option A (recommended): Install CLI globally via `mint` or `mise`**
```bash
# Install once
mint install github.com/[org]/ScreenAuditKit@1.0.0

# Run anywhere
screenaudit validate --screenshots ...
```

**Option B: Use swift run on the resolved dependency**
```bash
swift run --package-path "$(swift package show-bin-path)" screenaudit validate ...
```

**Option C: Maintain a pinned local checkout**
```bash
# Check out next to the monorepo
git clone --branch 1.0.0 https://github.com/[org]/ScreenAuditKit.git ../ScreenAuditKit-cli
# Update adapter scripts to use ../ScreenAuditKit-cli as the package path
```

**Recommended: Option A** (mint / mise). It decouples CLI version from library version
and avoids monorepo workspace complexity.

Update `utility/validate_screen_audit.sh`:
```bash
# Old (local package)
swift run --package-path "$SCREEN_AUDIT_PACKAGE" screenaudit validate ...

# New (globally installed via mint)
mint run ScreenAuditKit@1.0.0 screenaudit validate ...
# or just:
screenaudit validate ...
```

### Step 7: Remove the local package from the monorepo

```bash
# After confirming the SPM dependency works and CI passes:
git rm -r ScreenAuditKit/
git commit -m "Remove local ScreenAuditKit (now external dependency v1.0.0)"
```

### Step 8: Smoke test the full pipeline

```bash
# Confirm CI still works end-to-end
bash utility/screenaudit_doctor.sh
bash utility/validate_screen_audit.sh --ocr none
```

---

## 4. Migration Steps — NativeUIAuditKit

Follow the same structure as ScreenAuditKit. Additional considerations:

### Step 1: Decide on the model package

Before extraction, decide whether `NativeUIAuditKitModels` is:
- A **subpackage** in the same repo (simpler, harder to version independently)
- A **separate repo** (cleaner, necessary if model files are large binary targets)

Recommended: separate repo, because `.mlpackage` binary targets are large and should not
gate every source-only change to the detector logic.

### Step 2: Handle the dataset directory

The dataset directory (`NativeUIAuditKit-Dataset/`) is gitignored and never committed.
Before extraction, document its storage location in `Research/NativeUIElementDetection.md`
Section 6.2 and ensure a team member has a backup or the dataset can be regenerated from
the generator app.

### Step 3: Follow ScreenAuditKit steps 1–8

Substitute `NativeUIAuditKit` for `ScreenAuditKit` in every step.

---

## 5. Fastlane Integration Post-Migration

### Current state (local packages)

```ruby
# fastlane/Fastfile excerpt
sh("bash '#{SCREEN_AUDIT_CHECK}' --ocr vision")
```

`SCREEN_AUDIT_CHECK` resolves to `utility/validate_screen_audit.sh` which runs:
```bash
swift run --package-path "$ROOT/ScreenAuditKit" screenaudit validate ...
```

### Post-migration state (external CLI)

```ruby
# fastlane/Fastfile — no change needed if using global install
sh("bash '#{SCREEN_AUDIT_CHECK}' --ocr vision")
```

`utility/validate_screen_audit.sh` updated to:
```bash
# Check for CLI availability
if ! command -v screenaudit &>/dev/null; then
  echo ""
  echo "  ┌─────────────────────────────────────────────────────────────┐"
  echo "  │  ScreenAuditKit CLI not found.                              │"
  echo "  │                                                             │"
  echo "  │  Install it with:                                           │"
  echo "  │    mint install github.com/[org]/ScreenAuditKit@1.0.0       │"
  echo "  │                                                             │"
  echo "  │  Or set SCREEN_AUDIT_PACKAGE to a local package path to     │"
  echo "  │  use a local checkout instead.                              │"
  echo "  └─────────────────────────────────────────────────────────────┘"
  echo ""
  exit 2
fi
screenaudit validate ...
```

This provides plain-language guidance without requiring the caller to know anything about
SPM or Swift package paths.

### NativeUIAuditKit fastlane integration (future)

When NativeUIAuditKit is ready, it will be integrated as an optional post-validate step.
The lane should degrade gracefully if the model package is not installed:

```bash
# In utility/validate_native_ui.sh (future)
if ! nativeuiaudit --version &>/dev/null 2>&1; then
  echo "[native-ui] NativeUIAuditKit CLI not installed — skipping native UI detection."
  echo "[native-ui] To enable: mint install github.com/[org]/NativeUIAuditKit"
  exit 0   # soft exit — not a CI failure
fi
nativeuiaudit validate ...
```

The key distinction: ScreenAuditKit failure = CI failure. NativeUIAuditKit not-installed = warning only.

---

## 6. Contract File Location Post-Migration

Currently: `RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json`

After extraction, the contract file stays in RA11y — it is RA11y-specific data, not package code.
The `--contracts` CLI flag accepts any path; the RA11y adapter scripts continue to point to the
same file location. No change needed.

If contracts grow per-platform (tvOS, macOS), keep them in `RA11y-iOS/RA11y-iOSUITests/` with
clear naming: `ScreenAuditContracts-tvOS.json`, `ScreenAuditContracts-macOS.json`.

---

## 7. Rollback Strategy

### If ScreenAuditKit extraction breaks CI

1. Reinstate the local package: `git checkout HEAD~1 -- ScreenAuditKit/`
2. Revert `utility/validate_screen_audit.sh` to the local `--package-path` invocation
3. Open an issue in the standalone repo with the specific failure
4. Fix in the standalone repo, cut a patch release, then re-attempt extraction

### If SPM resolution is broken

The local package at `ScreenAuditKit/` (before deletion) can serve as a fallback:

```swift
// Temporary fallback in any Package.swift that imports ScreenAuditKit
.package(path: "../ScreenAuditKit")  // local path while SPM issue is resolved
```

---

## 8. Post-Migration Repository Structure

### Standalone ScreenAuditKit repo

```
ScreenAuditKit/
├── .gitignore
├── AGENTS.md               ← AI/contributor rules (self-contained)
├── CHANGELOG.md            ← public API history
├── LICENSE                 ← MIT or Apache 2.0
├── Package.swift
├── README.md
├── Tasks.md                ← milestone tracking (self-contained)
├── Docs/
│   └── FeatureWalkthrough/ ← curated artifacts + images
├── Sources/
│   ├── ScreenAuditKit/     ← library (no RA11y)
│   └── screenaudit/        ← CLI executable
├── Tests/
│   ├── ScreenAuditKitTests/
│   └── ScreenAuditCLITests/
└── Utility/
    └── export_feature_walkthrough.sh
```

### Standalone NativeUIAuditKit repo

```
NativeUIAuditKit/
├── .gitignore
├── AGENTS.md
├── LICENSE
├── Package.swift
├── README.md
├── Tasks.md
├── Research/
│   ├── NativeUIElementDetection.md
│   ├── References.md
│   └── CoordinateSpike.md          ← written during Phase 1
├── Sources/
│   └── NativeUIAuditKit/
└── Tests/
    └── NativeUIAuditKitTests/
```

### RA11y monorepo after extraction

```
RA11y/
├── RA11y-iOS/
│   └── RA11y-iOSUITests/
│       └── ScreenAuditContracts.json   ← stays here (RA11y-specific)
├── fastlane/
│   └── Fastfile                        ← unchanged (calls adapter scripts)
└── utility/
    ├── validate_screen_audit.sh        ← updated to use global CLI
    ├── screenaudit_doctor.sh           ← updated path references
    └── validate_native_ui.sh           ← new (future, optional)
```

---

## 9. Timeline Guidance

| Phase | Recommended timing |
|---|---|
| Complete ScreenAuditKit Milestone F commit | Before any extraction |
| Create standalone ScreenAuditKit repo | When ready — no blocker |
| RA11y consuming ScreenAuditKit as SPM dependency | After repo creation + CI smoke test |
| Remove local ScreenAuditKit from monorepo | After RA11y SPM dependency is stable for ≥1 sprint |
| NativeUIAuditKit Phase 6 (CoreML detector) | 3–6 months from scaffold |
| NativeUIAuditKit extraction | After Phase 6 complete |

---

## 10. Key Invariants to Preserve Through Migration

1. **Contracts are data, not code.** `ScreenAuditContracts.json` stays in RA11y regardless of where ScreenAuditKit lives.
2. **Adapter scripts are RA11y's responsibility.** `utility/validate_screen_audit.sh` is an RA11y file that calls ScreenAuditKit — it stays in RA11y.
3. **CLI exit codes are stable.** Never change `0=success`, `1=validation-failed`, `2=usage-error`, `3=input-error`, `4=runtime-error`. Fastlane depends on these.
4. **Tests run offline.** Both packages' tests must pass with `swift test` and zero network access.
5. **Feature walkthrough curates itself.** After extraction, `swift test && swift run screenaudit export-feature-walkthrough` inside the standalone repo must still produce the correct `Docs/` artifacts.
