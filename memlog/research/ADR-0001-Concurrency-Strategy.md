# ADR-0001: Concurrency Strategy for RA11y

Date: 2026-02-22
Status: Accepted

## Context

RA11y targets Swift 6 with strict concurrency. The iOS app target sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, while `RA11yCore` is a Swift
package shared across platforms. We need a consistent, low-risk approach to
concurrency that preserves UI responsiveness, avoids data races, and keeps
tests deterministic.

## Decision

Adopt the following concurrency strategy across the codebase:

1. **Structured Concurrency First**
   - Prefer `Task {}` scoped to the caller over `Task.detached`.
   - Child tasks inherit actor isolation unless explicitly opted out.

2. **Explicit Isolation Boundaries**
   - Treat UI and view-model code as `@MainActor` unless a narrower scope is
     justified.
   - Keep non-UI work in actors or nonisolated helpers as appropriate.

3. **Sendable Correctness**
   - Ensure values that cross task or actor boundaries are `Sendable`.
   - Avoid `@unchecked Sendable` unless required and paired with a documented
     invariant plus a follow-up ticket to remove it.

4. **Avoid Unsafe Isolation Escapes**
   - Avoid `nonisolated(unsafe)` unless a clear, documented rationale exists.
   - Prefer encapsulating shared mutable state inside actors.

5. **Cancellation and Responsiveness**
   - Check `Task.isCancelled` in long-running work and loops.
   - Do not block the main actor; move blocking I/O or expensive computation off
     the main actor and back only for UI updates.

6. **Documentation and Tests**
   - Document concurrency requirements in doc comments for internal/public async APIs.
   - Add or update tests that verify ordering, cancellation, and isolation.

## Consequences

- Slightly more up-front effort to model isolation, but fewer race conditions.
- Safer defaults for UI and async workflows.
- Clearer guidance for code reviews and future contributors.

## Alternatives Considered

- Relaxing strict concurrency or relying on `@preconcurrency` broadly.
  - Rejected: obscures data races and makes behavior harder to reason about.
- Heavy use of `Task.detached`.
  - Rejected: weak isolation guarantees and harder cancellation semantics.

## Follow-Ups

- Perform a concurrency audit of `RA11yCore` and `RA11y-iOS` using these rules.
- Track any required `@preconcurrency` or `@unchecked Sendable` as explicit tickets.

## References

- https://github.com/AvdLee/Swift-Concurrency-Agent-Skill
