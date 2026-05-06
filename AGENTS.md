# RA11y — Agent & Contributor Guidelines

This file governs how AI agents and contributors work in this repository.
Follow every section. These are not suggestions.

---

## Precedence

If any guidance below conflicts, the repository operational rules in this file take precedence for work in this repo.
The SwiftUI rules are intended for design and implementation guidance and should not override repo safety or workflow rules.

### How coding agents discover this file

- **OpenAI Codex** loads **`AGENTS.md`** from the repository root (and parent paths) automatically—no duplicate policy file needed for Codex.
- **Anthropic Claude Code** loads **`CLAUDE.md`** by default; this repo keeps a **short root `CLAUDE.md`** that points here so behavior stays single-source.
- **Cursor** uses **`.cursor/rules/agents-md-authority.mdc`** to require following this document.

---

## Project Structure

- `RA11y-iOS/` — iOS app target and Xcode project (`RA11y-iOS.xcodeproj`).
- `RA11yCore/` — Shared Swift package. All platform-agnostic logic lives here.
- `NativeUIAuditKit/` — Local Swift package (research scaffold). Native Apple UI element detector, pre-CoreML model. See its own `AGENTS.md` and `Tasks.md`.
- `RA11y.xcworkspace` — Workspace that ties the iOS app and RA11yCore together. Always open this.
- `utility/` — Build and test scripts, including fastlane adapter scripts for external CLI tools.
- `build_results/` — Script output. Gitignored.
- `memlog/` — Project notes, requirements, ticket breakdown, and design docs.

Future platform targets follow the same convention: `RA11y-macOS/`, `RA11y-tvOS/`,
each with its own `.xcodeproj` referenced by the workspace.

**ScreenAuditKit is an external dependency** (extracted from this monorepo). It is not in this
directory. See the "External CLI Tools" section below for installation and fastlane integration.

---

## External CLI Tools

RA11y's fastlane and utility scripts depend on external Swift CLI tools that are **not** in this
repository. This section documents what they are, where they live, how to install them, and how
the adapter scripts call them.

---

### ScreenAuditKit — `screenaudit` CLI

**Repository:** `https://github.com/SerialForBreakfast/ScreenAuditKit`  
**Current version in use:** `1.0.0`  
**Purpose:** Deterministic screenshot validation against JSON contracts. Detects missing text,
dimension mismatches, rendering artifacts, baseline drift, and quest flow violations.  
**Platform:** macOS only. Not imported into the iOS app — used only by CI and fastlane.

#### Installation

The `screenaudit` binary must be on `PATH` before running any fastlane lane that calls
`utility/validate_screen_audit.sh`.

**Option A — Build from the tagged release (current approach):**
```bash
git clone --depth 1 --branch 1.0.0 https://github.com/SerialForBreakfast/ScreenAuditKit.git /tmp/ScreenAuditKit-1.0.0
swift build -c release --package-path /tmp/ScreenAuditKit-1.0.0
cp /tmp/ScreenAuditKit-1.0.0/.build/release/screenaudit /opt/homebrew/bin/screenaudit
screenaudit --version   # must print 1.0.0
```

**Option B — mint (preferred once mint is installed):**
```bash
brew install mint
mint install SerialForBreakfast/ScreenAuditKit@1.0.0
screenaudit --version
```

To upgrade to a new version, repeat the same steps with the new tag. The adapter script
reads whatever `screenaudit` binary is on PATH — there is no version pin inside this repo.

#### Verification

```bash
screenaudit --version          # 1.0.0
screenaudit --help             # shows validate / export-feature-walkthrough commands
bash -n utility/validate_screen_audit.sh   # syntax check the adapter
```

#### How the adapter script works (`utility/validate_screen_audit.sh`)

```
SCREEN_AUDIT_PACKAGE env var set and is a directory?
  └─ yes → swift run --package-path "$SCREEN_AUDIT_PACKAGE" screenaudit …  (local dev override)
  └─ no  → screenaudit on PATH?
             └─ yes → screenaudit …                                          (normal production path)
             └─ no  → plain-English error box + exit 2
```

`SCREEN_AUDIT_PACKAGE` is only needed if you are actively developing ScreenAuditKit locally.
In normal CI and developer use it should be unset.

**OCR mode** (controls whether Apple Vision reads text from screenshots):

| Invocation | OCR behaviour |
|-----------|---------------|
| `--ocr none` | Skip OCR; text rules emit skipped-info findings |
| `--ocr vision` | Run VNRecognizeTextRequest on each PNG |
| `RA11Y_SCREEN_AUDIT_PROFILE=ci` (no flag) | Defaults to `vision` |
| No flag, no env var | Defaults to `none` |

#### Fastlane integration

```ruby
# fastlane/Fastfile
SCREEN_AUDIT_CHECK = "../utility/validate_screen_audit.sh"

lane :screen_audit do
  sh("bash '#{SCREEN_AUDIT_CHECK}' --ocr vision")
end
```

The `screenshots` lane calls `validate_screen_audit.sh` after capture. The `screen_audit`
lane can be run standalone at any time against committed screenshots in `docs/screenshots/`.

#### ScreenAuditKit contracts file

`RA11y-iOS/RA11y-iOSUITests/ScreenAuditContracts.json` — stays in this repo permanently.
It is RA11y-specific data, not package code. The `--contracts` flag in the adapter script
always points here.

Run `utility/screenaudit_doctor.sh` before a full audit to catch contract / screenshot
catalog drift without running the full validation pipeline.

#### Updating ScreenAuditKit

When a new version of ScreenAuditKit is released:
1. Build and install the new binary (Option A or B above).
2. Run `swift test --package-path /tmp/ScreenAuditKit-<version>` to confirm tests pass.
3. Run `bash utility/validate_screen_audit.sh --ocr none` against existing screenshots
   to confirm no contract regressions before merging any app changes.
4. Update this section and `memlog/research/PackageMigration-ScreenAuditKit-NativeUIAuditKit.md`
   with the new version number.

---

### NativeUIAuditKit — future `nativeuiaudit` CLI

**Repository:** `https://github.com/SerialForBreakfast/NativeUIAuditKit`  
**Status:** Research scaffold — Phase 0. No CoreML model exists yet.  
**Do not install or integrate into fastlane** until Phase 6 (CoreML detector, mAP@0.5 ≥ 0.70)
is complete. See `NativeUIAuditKit/Tasks.md` for the phase roadmap.

When NativeUIAuditKit is eventually integrated, its fastlane lane will be **optional** — a
missing CLI is a warning, not a CI failure (unlike ScreenAuditKit).

The local `NativeUIAuditKit/` directory in this repo is the active development scaffold.
It will be removed from the monorepo (like ScreenAuditKit was) once Phase 4+ is stable and
the package is extracted to its standalone repo.

---

## System Safety — Prohibited Commands

The following commands MUST NEVER be run without explicit written approval
from the user in the current conversation. State the exact command and its
risk before asking. Do not run it until the user confirms.

### Elevated Privileges
- Any command prefixed with `sudo`
- Any command using `su`

### Daemon / Service Termination
- `killall` or `kill` targeting any Apple system daemon:
  - `com.apple.CoreSimulator.CoreSimulatorService`
  - `simdiskimaged`
  - Any `com.apple.*` launchd service
- Never use `-9` (SIGKILL) on system services. Always prefer `-TERM` and
  only after explicit user approval.

### Simulator State Modification
- `xcrun simctl erase` (any form)
- `xcrun simctl delete`
- `xcrun simctl shutdown all`
- `fastlane snapshot reset_simulators`
- Any command that wipes or recreates simulator devices

### Platform / Runtime Downloads
- `xcodebuild -downloadPlatform`
- `xcodebuild -downloadAllPlatforms`
- Any action that may trigger a download larger than 100 MB
- Always ask the user before running anything that could trigger a large download

### Xcode Toolchain Modification
- `xcode-select --switch` / `xcode-select -s`
- `xcodebuild -runFirstLaunch`
- `xcodebuild -license accept`

### Git Is Read-Only for Agents

Agents MUST NEVER perform git writes in this repository. Human oversight is
required for any modification to the git index, branches, history, remotes, or
working tree through git.

Allowed git usage is read-only inspection, such as:
- `git status`
- `git diff`
- `git log`
- `git show`
- `git branch --show-current`
- `git ls-files`

Prohibited git usage includes, but is not limited to:
- `git add`
- `git commit`
- `git checkout` / `git switch`
- `git restore`
- `git reset`
- `git merge`
- `git rebase`
- `git stash`
- `git rm`
- `git mv`
- `git pull`
- `git push`
- Any command that writes `.git/index`, changes branch state, changes history,
  stages files, unstages files, rewrites files through git, or contacts a remote
  to modify repository state.

### Debugging System Issues (Simulators, CoreSimulator, Xcode)

When diagnosing system-level failures (simulator services down,
CoreSimulatorService crashes, missing runtimes):

1. **Read-only diagnosis first.** Only run commands that query state:
   - `xcodebuild -showdestinations`
   - `plutil -p <path>` to read plists
   - `uptime`, `xcode-select -p`
   Never run modification commands until read-only diagnosis is complete
   and presented to the user.

2. **Present findings before acting.** Summarize what the diagnostic output
   shows, state the hypothesis, and ask which fix to apply.

3. **Never run simctl commands that may hang.** If `xcrun simctl` does not
   return promptly in a non-interactive context, it is likely blocking on
   a broken CoreSimulatorService. Stop. Do not kill the process — inform
   the user and let them handle it.

4. **Treat simulator instability as a system issue, not a code issue.**
   Do not modify project files, Fastfile, or CI config in response to
   simulator service failures unless the user explicitly requests it.

---

## File System Boundaries

All files created or modified by AI agents MUST stay inside the project
directory. This rule applies to every agent, every sub-agent, and every
tool call — without exception.

### Rule: Never Write Outside the Project Root

The project root is the directory containing this AGENTS.md file.

NEVER create, write, or move files to any of the following:
- `/tmp/` or any system temporary directory
- `~/Desktop/`, `~/Downloads/`, `~/Documents/`, or any home directory path
- `/var/`, `/usr/`, `/etc/`, or any system path
- Any absolute path that is not inside the project root
- Any relative path that escapes the project root via `../`

### Approved Locations for Working Files

When a task requires scratch space, intermediate output, or generated
artefacts, use directories inside the project:

| Purpose | Location |
|---|---|
| Design docs, specs, ADRs | `memlog/` |
| UX mockup PNGs (Phase 3) | `memlog/requirements/Design/MockupScreens/` |
| Mockup HTML (optional only) | `memlog/requirements/Design/Mockups-v2/` |
| Generated assets (pre-import) | `memlog/requirements/Design/Assets/` |
| Build and test output | `build_results/` |
| Utility scripts | `utility/` |

### Enforcement

If a task appears to require writing outside the project directory, STOP.
Reframe the task so all output lands inside the project. If it genuinely
cannot be done inside the project, ask the user before proceeding.

This rule exists to ensure the repository is the single source of truth
and that agent actions are fully auditable via git.

---

## Illustrated quest assets — authorship (mandatory)

This applies to **narrative / game illustration** in `Assets.xcassets`: backgrounds,
creatures, props, ward rings, hub thumbnails, illustrated VFX, and any PNG meant
to read as **designed art** in a quest.

### MUST — where creative pixels come from

- **LLM image generation** in a directed session (same class of tool used to
  produce Phase 3 mockups), **or**
- **Human** illustration / commissioned export / hand-painted PNGs that follow
  the Phase 4 prompt sheet.

The authoring agent or artist is responsible for style, composition, and
readability. That work is **not** replaceable by geometry, gradients, or
noise in a script.

### MUST NOT — script-synthesized “art”

Agents and contributors MUST **not** ship or recommend shipping quest art that
was **created by code** for production use, including:

- Procedural drawing (e.g. Pillow `ImageDraw`, synthetic blobs, vectoroids
  passed off as creatures).
- Gradient-only or mathematically generated backgrounds presented as final
  illustrated masters.
- New “procedural shippable art” generators for quests.

Historical files such as `utility/banishment_procedural_placeholder.py` are
**legacy reference only**. Do **not** use them to refresh production assets or
suggest them as the primary path.

### ALLOWED — mechanical pipeline only

Scripts may **validate**, **normalize**, or **fit pixels** that already exist
in an authored PNG. Examples: `utility/qa_*` checks, `utility/ensure_png_rgba.py`,
`utility/remove_white_background.py`, and `utility/ingest_llm_banishment_pngs.py`
(resize/fit **pre-generated** exports into catalog dimensions). These tools MUST
**not** invent imagery.

**Mockup cropping** (`utility/import_banishment_mockups_to_assets.py`) may be
used only as a **bootstrap or emergency** path when LLM/human masters are not
yet available; it is **not** the preferred long-term source of illustrated
catalog art. Prefer regenerating assets from the Phase 4 prompt sheet via LLM or
human export, then ingest.

### Agent behavior

When a task asks for new or updated quest art, the agent MUST produce or direct
**authored** imagery (LLM image tool in Cursor, or explicit handoff to a human
artist). The agent MUST NOT substitute procedural Python art and MUST NOT
present script-drawn placeholders as the solution to “make it look like the
mockups.”

---

## Scripting Language Policy

Prefer standard shell tools over interpreted scripting languages. This
reduces interpreter version dependencies, limits arbitrary code execution
surface, and keeps scripts auditable by anyone with basic shell knowledge.

### Maintainer toolchain (agents — required)

The primary maintainer reviews agent work using **bash**, **standard Unix
command-line tools**, and **Swift / Xcode** (`swift`, `xcodebuild`, etc.)
only. They do **not** use Python or other extra runtimes for day-to-day
review.

**Agents MUST follow that boundary for anything they *run* in the shell:**

- **Allowed:** `bash` / `sh`, POSIX and macOS CLI (`grep`, `sed`, `awk`, `jq`,
  `plutil`, `xcrun`, `xcodebuild`, `swift`, committed `utility/*.sh`, and
  other tools that are clearly “plain Unix + Apple toolchain.”
- **Forbidden for improvised use:** `python`, `python3`, `ruby`, `node`,
  `npm`, `npx`, or similar **one-liners and ad-hoc scripts**—including
  “quick” JSON/XML validation—so the maintainer can reason about safety
  without learning another language. Use `./utility/build_and_test.sh`,
  Xcode build output, or shell tools (`plutil`, etc.) instead.
- **Exception:** Run **only** the already-committed, documented Python
  utilities under `utility/` when the task is explicitly the asset/PNG
  pipeline listed below—not new `python3 -c '…'` invocations.

### Preferred Tools (use these first)

- **Text processing:** `awk`, `sed`, `grep`, `ripgrep (rg)`, `cut`, `tr`, `sort`, `uniq`
- **File operations:** `find`, `ls`, `cp`, `mv`, `mkdir`, `rm`, `xargs`
- **Data / JSON:** `jq`
- **Network:** `curl`
- **Archives:** `tar`, `unzip`, `zip`
- **Conditionals / loops:** `bash` built-ins (`if`, `while`, `for`, `case`)
- **String / math:** `expr`, `printf`, parameter expansion, arithmetic expansion

### When an Interpreted Language Is Acceptable

Do not write Python, Perl, Ruby, Node.js, or any other interpreted language
script unless ALL of the following are true:

1. The task is genuinely impossible or severely impractical with shell tools
2. An explicit interpreter version is already confirmed present on the host
3. The user explicitly approves the use of that language for the task

Existing project scripts that already use Python are grandfathered **for
mechanical pipeline work only** (never for synthesizing illustrated quest art;
see **Illustrated quest assets — authorship** above):

- `utility/remove_white_background.py` — approved, do not rewrite
- `utility/transparent_edge_dark_matte.py`, `utility/transparent_edge_midgrey_matte.py` — edge flood for black / grey checkerboard export beds on catalog sprites (mechanical cleanup only)
- `utility/ensure_png_rgba.py` — batch RGBA normalization for `Assets.xcassets` composited art (uses edge logic from `remove_white_background.py`)
- `utility/qa_banishment_png_assets.py`, `utility/qa_crystal_resonance_png_assets.py` — validation only
- `utility/ingest_llm_banishment_pngs.py` — fit pre-authored LLM/human PNGs into catalog sizes
- `utility/import_banishment_mockups_to_assets.py` — bootstrap crop from mockups only; not the preferred authorship path
- `utility/build_and_test.sh` — shell, already compliant

### For New Automation

Write new scripts as `bash`. If a one-liner requires a complex transform,
reach for `awk` or `jq` before reaching for Python. A 10-line `awk` program
is more auditable and portable than a 10-line Python script for the same task.

### Rationale

Interpreted language scripts can execute arbitrary code, introduce supply
chain risk via imports, and behave differently across interpreter versions.
Shell tools from POSIX and the standard macOS toolchain have a stable,
well-understood security model and are always available on the host.

---

## Simulator Detection — Required Pattern

Hardcoded simulator names (e.g., `"iPhone 17"`, `"iPad (A16)"`) MUST NOT
appear in any script, Fastfile, utility file, or CI config as the sole
destination selector. Simulator names change with every Xcode/iOS release
and break silently.

### Rule: Always Discover, Never Hardcode Bare

Any code that selects a simulator MUST follow this pattern:
1. Query what is actually available at runtime via `xcrun simctl list devices available --json`
2. If a **persisted last-working UDID** for that device family (see below) still appears in the listing, use it and skip the preference list for stable day-to-day runs.
3. Match against a preference list (most to least preferred)
4. Fall back to the best available match if no exact match is found
5. Fail loudly — listing discovered devices — if no match exists at all

A preference list of names may be hardcoded. The final resolved device must not be.

### Use UDID, Not Name, as the xcodebuild Destination

Once a simulator is resolved, use its UDID rather than its name:

```bash
# GOOD — stable, resolved at runtime
xcodebuild test -destination "platform=iOS Simulator,id=$UDID" ...

# BAD — breaks when Xcode updates simulator names
xcodebuild test -destination "platform=iOS Simulator,name=iPhone 17" ...
```

### Approved Fallback Hierarchy (preference order)

iPhone: `iPhone 17` → `iPhone 16 Pro` → `iPhone 16` → `iPhone 15 Pro` → `iPhone 15` → any iPhone

iPad: `iPad Pro (13-inch)` → `iPad Pro (12.9-inch)` → `iPad Pro` → `iPad Air` → any iPad

If no simulator of the required family exists, STOP and report:
- The list of available simulators
- Which family was needed and why
- What the user must do (open Simulator.app, check Xcode → Settings → Platforms)

Do NOT attempt to create simulators, download runtimes, or modify simulator
state without explicit user approval. Repo scripts never call
`xcodebuild -download*`, `simctl create`, or other commands that install
runtimes or provision new devices. If macOS or Xcode shows a system dialog
such as "Verifying … simruntime", that is host-level validation of an
already-installed runtime — not something this repository triggers.

### Persist Last-Working UDID (stable reuse)

`utility/build_and_test.sh` and `fastlane/Fastfile` store the resolved UDID
per family in `~/.ra11y/last_simulator_iPhone.udid` and
`~/.ra11y/last_simulator_iPad.udid` (set `RA11Y_SIMULATOR_STATE_DIR` to use a
different directory). The next invocation reuses that UDID if it is still
listed as available, then falls back to the preference hierarchy above.

If the first `simctl` query fails or returns empty output, scripts retry once
after a one-second delay (transient CoreSimulator stalls).

### Files That Must Follow This Pattern

When modifying any of the following, verify that simulator detection is
dynamic and follows the rules above:
- `fastlane/Fastfile`
- `utility/build_and_test.sh`
- `.github/workflows/ios-ci.yml`
- `.github/workflows/ios-screenshots.yml`

---

## Build, Test, and Development

Never open or interact with the Xcode GUI. Use the CLI exclusively.

```bash
# Full build and test (Core + iOS simulator)
utility/build_and_test.sh

# Core only — fast, no simulator needed (runs natively on macOS)
utility/build_and_test.sh --only-core

# iOS only
utility/build_and_test.sh --only-ios

# Custom simulator
utility/build_and_test.sh --sim "iPhone 16 Pro"

# Clean before build
utility/build_and_test.sh --clean

# Verbose (streams xcodebuild output)
utility/build_and_test.sh --verbose

# List workspace schemes
utility/build_and_test.sh --list-schemes

# Capture screenshots (fastlane snapshot)
bundle exec fastlane screenshots

# Swift package build/test only (fastest)
swift build --package-path RA11yCore
swift test --package-path RA11yCore
```

After every substantive change, validate ALL targets pass before declaring done.
A passing Core build is not sufficient if the iOS build fails, and vice versa.

---

## Screenshot Automation Contract

Screenshot automation must remain deterministic and aligned across docs, tests, and fastlane.

Authoritative files:
- `RA11y-iOS/RA11y-iOS/App/iOSScreenshotScene.swift`
- `RA11y-iOS/RA11y-iOSUITests/ScreenshotRouteCatalog.md`
- `RA11y-iOS/RA11y-iOSUITests/RA11y_iOSScreenshots.swift`
- `fastlane/Fastfile` (`UI_TEST_IDS` allowlist)

End-to-end workflow (catalog + Fastlane + ScreenAuditKit checks) is summarized in `memlog/research/ScreenshotAndScreenAudit-GoldenPath.md`.

ScreenAuditKit is an **external CLI tool** (`screenaudit` binary on PATH). Installation,
configuration, and fastlane wiring are documented in the "External CLI Tools" section above.
Before working on screenshot validation, confirm `screenaudit --version` returns `1.0.0`.

Required rules:
- Any change to screenshot-covered UI routes, accessibility identifiers, or launch args MUST update all four files in the same change.
- New screenshot-covered screens MUST include:
  - A stable root accessibility identifier.
  - A deterministic `-screenshotScene <sceneID>` boot path declared in `iOSScreenshotScene.swift`.
  - A route-catalog row with screenshot file name, scene ID, and root anchor identifier.
- Before running `fastlane screenshots`, run:
  - `utility/validate_screenshot_contract.sh`
- When using ScreenAuditKit rules (`ScreenAuditContracts.json`), run `utility/screenaudit_doctor.sh` to catch catalog or flow ID drift before a full audit.

---

## Before Writing Any Code

1. **Search first.** Before creating a protocol, class, enum, struct, or file,
   search the codebase for an existing implementation.
   ```bash
   rg "ProtocolName|ClassName" --type swift
   ```

2. **Check existing repos.** If solving a non-trivial problem, search for existing,
   actively maintained open-source solutions before implementing from scratch.
   Offer the option to the user. Use SPM only — never CocoaPods or Carthage.
   For SPM dependencies, always use an exact compatible version tag.

3. **Check target membership.** When adding a new file, verify it is included in
   the correct Xcode target(s). `PBXFileSystemSynchronizedRootGroup` handles
   auto-inclusion for `RA11y-iOS` subdirectories, but confirm for new top-level
   folders and for `RA11yCore` test targets.

4. **Update `memlog/DirectoryTree.txt`** when adding, moving, or removing files
   or directories of significance.

---

## Naming Conventions

- Swift: 4-space indentation, `UpperCamelCase` types, `lowerCamelCase` members.
- **OS-prefixed source files** for all platform-specific code:
  `iOSRootView.swift`, `macOSRootView.swift`, `tvOSRootView.swift`.
  This is mandatory — not optional — for any file that lives in a platform target.
- Descriptive names. A name should make the purpose obvious without a comment.
  `voiceOverStateProvider` not `provider`. `gameSessionCoordinator` not `coord`.
- No abbreviations unless they are universally understood (e.g., `URL`, `ID`).

---

## Documentation

- Every `public` and `internal` type, property, and function must have a
  doc comment using Xcode QuickHelp format (`///`).
- Comments explain **intent and constraints**, not what the code literally does.
  Do not write `// increment counter` above `count += 1`.
- When a function has concurrency requirements, document them explicitly:
  - Which actor or thread it must be called from.
  - Whether it can be called from a non-isolated context.
  - How its async behavior interacts with callers.
- Do not add emojis to code, comments, or log messages.

---

## Access Control

- Be intentional. Default to the most restrictive level that allows the feature to work.
- `public` only when the symbol must be accessible across module boundaries.
- `internal` (default) for cross-file access within the same module.
- `private` or `fileprivate` for implementation details.
- When changing an access level on any type or member, search all usage sites
  and update them before committing.

---

## Mutability

- Prefer `let` over `var`. Only use `var` when mutation is genuinely required.

---

## Concurrency Strategy (Swift 6)

Use the Swift Concurrency Agent Skill principles as guardrails when designing or reviewing concurrency.
These rules are additive to the rest of this document.

### Audit Focus (Before Changes)
- Identify actor isolation boundaries (App target is `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- Map async entry points and background work; avoid broad `@MainActor` where a narrower scope fits.
- Confirm `Sendable` correctness for values crossing task or actor boundaries.

### Implementation Rules
- Prefer structured concurrency (`Task {}` scoped to the caller) over `Task.detached`.
- Avoid `nonisolated(unsafe)` and `@unchecked Sendable` unless a documented invariant exists.
- Keep actor-isolated critical sections minimal; move heavy work to nonisolated helpers.
- Always handle cancellation in long-running tasks and loops (`Task.isCancelled`).
- Never block in async contexts; move blocking I/O off the main actor.

### Documentation & Review
- Document isolation requirements in doc comments for any public/internal async API.
- When adding concurrency workarounds (e.g., `@preconcurrency`), add a follow-up ticket.
- Add or update tests that validate concurrent behavior (ordering, cancellation, thread-safety).

---

# RA11y - SwiftUI Agentic Rules (Distilled)
Date: 2026-02-21
Source: Distilled from AvdLee/SwiftUI-Agent-Skill (swiftui-expert-skill)

Purpose
=======
This document captures the useful, SAFE, non-destructive SwiftUI guidance from the SwiftUI Agent Skill.
It is intended to guide AI-assisted work inside this repo without introducing risky behaviors (broad refactors,
architectural mandates, tooling commands, or secret access).

Scope
=====
- SwiftUI-focused guidance only.
- iOS-first (RA11y MVP), with modern APIs preferred.
- When bridging to UIKit is required, keep it minimal and explicitly justified.

Non-negotiable Safety Rules (Agent Behavior)
============================================
1) No tool / command instructions
- Do not instruct running shell commands, curl/wget, installing packages, or using external tools.
- No “automated profiling steps.” You can mention Instruments exists, but never prescribe steps.

2) No architecture mandates
- Do not enforce MVVM/MVC/VIPER, coordinators, routers, DI frameworks, or folder structures.
- You may suggest separating business logic for testability, without prescribing how.

3) Suggestions vs requirements
- Use MUST/NEVER only for correctness issues.
- Use CONSIDER/SUGGEST for optimizations.

4) Minimal-change bias
- Prefer the smallest change that fixes correctness, accessibility, or performance issues.
- Avoid large sweeping refactors unless explicitly requested.

SwiftUI Correctness Rules (High Signal)
=======================================

State Management (Modern)
-------------------------
- Prefer @Observable over ObservableObject for new code.
- Use @State for owned @Observable instances (not @StateObject).
- Always mark @State (and legacy @StateObject) properties as private.
- Never declare passed-in values as @State or @StateObject (they only take an initial value).
- Use @Binding ONLY when the child must modify parent state; otherwise use let.
- Use @Bindable when a view receives an @Observable object and needs bindings.
- @Observable classes may need @MainActor for SwiftUI safety unless the project uses Default Actor Isolation == MainActor.

Modern SwiftUI API Defaults
---------------------------
Prefer these modern APIs unless there is a specific, justified need for legacy behavior:
- foregroundStyle() instead of foregroundColor()
- clipShape(.rect(cornerRadius:)) instead of cornerRadius()
- NavigationStack instead of NavigationView
- navigationDestination(for:) for type-safe navigation
- Button instead of onTapGesture() (unless you need gesture location/count)
- .sheet(item:) for model-based sheet content (instead of .sheet(isPresented:))
- ScrollViewReader for programmatic scrolling with stable IDs
- Avoid UIScreen.main.bounds for sizing
- Avoid GeometryReader when alternatives exist (e.g., containerRelativeFrame)

View Composition
----------------
- Keep body pure: no side effects and no heavy logic.
- Prefer modifiers over switching entire view types for state changes (helps keep view identity stable).
- Extract complex views into subviews early for readability and better diffing.
- Prefer method references for actions (move inline logic into named functions).
- Prefer relative layout over hard-coded constants.
- Keep views context-agnostic (don’t assume screen size/presentation style).

Lists / ForEach (Stability is correctness)
------------------------------------------
MUST / NEVER rules:
- Always provide stable identity for ForEach.
- Never use .indices for dynamic content.
- Avoid variable view count per element inside ForEach (can break identity/animations).
- Avoid inline filtering inside ForEach; pre-filter and cache.
- Avoid AnyView inside list rows.
- Convert enumerated() sequences to arrays before ForEach.

Performance (Only when justified)
--------------------------------
Correctness-oriented performance rules:
- SwiftUI doesn’t compare before re-render: guard assignments to state so you only write when values change.
- In hot paths (scroll handlers / frequent updates), gate state updates by thresholds.

Optional optimizations (SUGGEST, don’t auto-apply):
- Equatable views for expensive subtrees.
- POD wrapper pattern for fast diffing (advanced).
- Suggest downsampling when encountering UIImage(data:) (only if relevant to current performance issue).

Animations
----------
- Prefer .animation(_:value:) (value-based) over deprecated broad animations.
- Use withAnimation for event-driven changes.
- Prefer transform animations (offset/scale/rotation) over layout changes for performance.

Liquid Glass (iOS 26+)
----------------------
- Only adopt glass effects when explicitly requested.
- Gate iOS 26+ APIs with #available and provide a sensible fallback.

Accessibility Defaults (RA11y Alignment)
========================================
These rules align the SwiftUI skill’s “accessibility best practices” with RA11y’s product goals.

- Interactive controls MUST have:
  - accessibilityLabel (user-facing name)
  - accessibilityHint when it clarifies the action
- Decorative imagery MUST be hidden from accessibility.
- Do not rely on color alone to convey meaning.
- Ensure Dynamic Type works end-to-end:
  - avoid fixed text sizes for critical content
  - avoid clipping/truncation in common large size categories
- Prefer semantic controls (Button, Toggle, Slider, etc.) over gesture-only interactions.

What to Avoid (Common Failure Modes)
====================================
- Don’t “optimize everything.” Performance changes must be motivated by an observed issue.
- Don’t rewrite app architecture while “improving SwiftUI.”
- Don’t introduce tooling/CLI steps into instructions.
- Don’t migrate to Liquid Glass styling unless requested.

Primary Source Pointers
=======================
- SwiftUI Expert Skill core guidelines and checklists:
  https://raw.githubusercontent.com/AvdLee/SwiftUI-Agent-Skill/main/swiftui-expert-skill/SKILL.md
- Agent guidelines (what the skill explicitly excludes / how to phrase guidance):
  https://raw.githubusercontent.com/AvdLee/SwiftUI-Agent-Skill/main/AGENTS.md
- Reference deep dives (state, lists, performance):
  https://raw.githubusercontent.com/AvdLee/SwiftUI-Agent-Skill/main/swiftui-expert-skill/references/state-management.md
  https://raw.githubusercontent.com/AvdLee/SwiftUI-Agent-Skill/main/swiftui-expert-skill/references/list-patterns.md
  https://raw.githubusercontent.com/AvdLee/SwiftUI-Agent-Skill/main/swiftui-expert-skill/references/performance-patterns.md
