# RA11y — Agent & Contributor Guidelines

This file governs how AI agents and contributors work in this repository.
Follow every section. These are not suggestions.

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
- Prefer value types (`struct`, `enum`) over reference types (`class`) unless
  identity, inheritance, or actor isolation is needed.
- Use optionals intentionally. `nil` should represent "absence of a value," not
  "I haven't initialized this yet." Avoid force-unwrap (`!`) in production code.

---

## Swift 6 Concurrency — Non-Negotiable

This project targets Swift 6 with full strict concurrency checking enabled.

1. **`async`/`await` only.** No GCD (`DispatchQueue`), no completion handlers,
   no `OperationQueue` for new code.

2. **`actor` for shared mutable state.** If multiple tasks can access mutable state,
   it must be inside an `actor`. Never use `objc_sync_enter` or manual locking.

3. **`@MainActor` for UI and routing.** All SwiftUI views, view models, and
   navigation code run on `@MainActor`. The iOS app target sets
   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` at the project level.

4. **No blocking in async contexts.** Never call synchronous, blocking APIs
   (heavy computation, synchronous I/O) from an `async` function without
   dispatching to a background task first.

5. **Cancellation.** Long-running tasks must check `Task.isCancelled` at
   meaningful intervals and exit cleanly. Never swallow cancellation.

6. **`Sendable` conformance.** Types shared across concurrency boundaries must
   conform to `Sendable`. Closures crossing actor boundaries must be `@Sendable`.

7. **No `@unchecked Sendable`.** This is a code smell and will be rejected.
   If you need to suppress a concurrency warning, understand why and fix the
   underlying issue instead.

8. **No `@preconcurrency`.** Treat its presence as a flag to fix, not a solution.

9. **`deinit` is not `@MainActor`.** Do not access `@MainActor`-isolated properties
   from `deinit`. Use `nonisolated(unsafe)` only for `Task` cancellation in `deinit`,
   where `Task.cancel()` is provably thread-safe.

---

## Dependency Injection

- Use constructor injection. Inject dependencies at the call site, not inside initializers.
- Determine whether a protocol abstraction is warranted before injecting a concrete type.
  A protocol makes sense when: (a) the dependency has a meaningful test double,
  or (b) the platform boundary requires it (e.g., `VoiceOverStateProvider`).
- When changing the signature of a protocol, always evaluate whether the protocol
  should change to match the implementation, or the implementation should conform
  to the existing protocol. Do not silently change the protocol to match the code.

---

## Testing

- Write tests for business logic. Do not write tests for trivial math, array
  counting, or behavior that the compiler already guarantees.
- Unit tests for `RA11yCore` live in `RA11yCore/Tests/RA11yCoreTests/`.
- Unit tests for the iOS app live in `RA11y-iOS/RA11y-iOSTests/`.
- Never skip or disable a test (`xtestSomething`, `.disabled`, `#if false`) to make
  a test suite pass. Fix the underlying issue.
- Test async code correctly: use `await #expect(throws:)` for throwing async
  expressions. Use `Task.sleep` (not `Task.yield`) for reactive async tests that
  require cooperative scheduling time.
- All targets must pass before a change is considered complete.

---

## When Changing Existing Code

- **Type changes:** If you change a type's name, access level, `async` qualifier,
  or protocol conformance, search all usage sites across the entire repo and
  update them. Do not leave stale call sites.
  ```bash
  rg "TypeName|methodName" --type swift
  ```
- **Async changes:** Document the concurrency contract in the doc comment.
  Trace all callers and verify the change does not introduce actor-isolation
  violations or require callers to add `await` they are missing.
- **Protocol vs implementation:** Before changing a protocol to match an
  implementation, explicitly question whether the implementation should instead
  be changed to conform to the protocol as designed.

---

## Design and Accessibility

- Use SF Symbols (`Image(systemName:)`) for iconography where an appropriate
  symbol exists. Do not use custom assets for standard UI concepts.
- No information conveyed by color alone. Shape, label, or pattern must reinforce
  any color cue.
- All interactive elements require `accessibilityLabel`. Add `accessibilityHint`
  when it adds actionable value beyond what the label already communicates.
- Decorative images: `accessibilityHidden = true`.
- Dynamic Type: use `Font.ra11y*` tokens from `RA11yCore`; never hardcode font sizes.
- VoiceOver reading order must be deterministic on every screen.

---

## Memlog

- `memlog/` is the authoritative record of requirements, decisions, and project state.
- `memlog/DirectoryTree.txt` must be updated when significant files or folders change.
- `memlog/requirements/TicketBreakdown.txt` is the active ticket tracker.
  Update ticket status (`[NEW]`, `[COMPLETE]`, etc.) when work is done.
- Before starting work on a ticket, read the relevant GameSpec, GameRules, and
  any referenced design tickets to understand the full context.

---

## Commit and Pull Request Guidelines

- Concise, imperative commit messages: `add GameSessionCoordinator for VO mid-game handling`.
- For UI changes, include screenshots or recordings in the PR description.
- Call out any change that affects: accessibility behavior, permissions, data persistence,
  or concurrency model.
- Never commit files that contain secrets or credentials.
