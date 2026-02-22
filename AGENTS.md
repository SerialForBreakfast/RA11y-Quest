# RA11y — Agent & Contributor Guidelines

This file governs how AI agents and contributors work in this repository.
Follow every section. These are not suggestions.

---

## Precedence

If any guidance below conflicts, the repository operational rules in this file take precedence for work in this repo.
The SwiftUI rules are intended for design and implementation guidance and should not override repo safety or workflow rules.

---

## Project Structure

- `RA11y-iOS/` — iOS app target and Xcode project (`RA11y-iOS.xcodeproj`).
- `RA11yCore/` — Shared Swift package. All platform-agnostic logic lives here.
- `RA11y.xcworkspace` — Workspace that ties the app and package together. Always open this.
- `utility/` — Build and test scripts.
- `build_results/` — Script output. Gitignored.
- `memlog/` — Project notes, requirements, ticket breakdown, and design docs.

Future platform targets follow the same convention: `RA11y-macOS/`, `RA11y-tvOS/`,
each with its own `.xcodeproj` referenced by the workspace.

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

## Simulator Detection — Required Pattern

Hardcoded simulator names (e.g., `"iPhone 17"`, `"iPad (A16)"`) MUST NOT
appear in any script, Fastfile, utility file, or CI config as the sole
destination selector. Simulator names change with every Xcode/iOS release
and break silently.

### Rule: Always Discover, Never Hardcode Bare

Any code that selects a simulator MUST follow this pattern:
1. Query what is actually available at runtime via `xcrun simctl list devices available --json`
2. Match against a preference list (most to least preferred)
3. Fall back to the best available match if no exact match is found
4. Fail loudly — listing discovered devices — if no match exists at all

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
state without explicit user approval.

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
