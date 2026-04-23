# Magic Tap: Bard's Interrupt Task Plan

Date: 2026-04-21

## Goal

Build a Magic Tap quest where the player is a bard interrupting enemy spells mid-chant. The quest teaches:

- Magic Tap is the two-finger double-tap shortcut.
- Magic Tap triggers the most obvious current action.
- Magic Tap should work even when VoiceOver focus is not on a specific button.
- Timing matters: wait for the release cue, then interrupt.

Working title: **Bard's Interrupt**.

## Product Shape

The player faces an enemy caster. The enemy chant moves through three states:

1. Murmur: spell is forming; too early to interrupt.
2. Rising: warning phase; prepare.
3. Release: interrupt window; Magic Tap now.

Magic Tap during Release breaks the spell. Magic Tap too early or too late produces a mistake and a teaching cue.

## Non-Negotiable Interaction Rules

- The actual trained input is Magic Tap: two-finger double-tap.
- The quest needs its own Magic Tap handler path, not a normal Button activation path.
- VoiceOver focus should not need to be on a specific visible control.
- Copy should say both "Magic Tap" and "two-finger double-tap" during onboarding.
- Do not implement rapid repeated tapping. One intentional Magic Tap per chant cycle.
- Provide visible, spoken, audio, and haptic state cues.

## Level Arc

### L1: Tutorial Interrupt

Purpose: teach the gesture and the release cue.

Flow:

- DM introduces Magic Tap.
- Enemy performs a slow chant.
- VoiceOver announces each phase: "Murmur", "Rising", "Release. Magic Tap now."
- Release window is wide.
- One successful interrupt clears the level.

Acceptance criteria:

- User can succeed with one Magic Tap.
- Early Magic Tap explains "Too early. Wait for release."
- Successful Magic Tap announces "Interrupted."
- VoiceOver focus location does not matter within the quest scene.

### L2: Decoy Rhythm

Purpose: teach not to panic-tap on any cue.

Flow:

- Enemy chant includes one fake peak before the real release.
- Fake peak uses different audio/haptic texture.
- User must wait for the true release cue.
- Three successful interrupts clear the level.

Acceptance criteria:

- Fake cue does not count as success.
- Early Magic Tap on fake cue records a mistake and restarts that chant.
- State copy distinguishes "rising" from "release" without over-explaining every time.
- Quest remains playable via VoiceOver only.

### L3: Timed Performance

Purpose: apply the skill under light pressure.

Flow:

- 45-second encounter.
- Multiple enemies or repeated chant cycles.
- Randomized but readable timing.
- Successful interrupts reduce threat/progress to victory.
- Misses add mistakes; timeout produces failed result.

Acceptance criteria:

- Completion records a GameSession result.
- Time and mistakes feed rank thresholds.
- Timer announcements do not overlap the release cue.
- Magic Tap remains responsive throughout the timed run.

## Visual Direction

Scene: small stage or tavern threshold facing a hostile caster.

Core visual elements:

- Bard focus object: lute, resonant strings, or glowing verse circle.
- Enemy caster silhouette with chant aura.
- Chant meter with three readable bands: Murmur, Rising, Release.
- Release state should be visually unmistakable: aura opens, rune brightens, or spell ring exposes a weak point.

Avoid:

- Generic progress bars as the primary visual.
- Button-first UI that implies the user should find and activate a control.
- Busy full-screen overlays that obscure the timing cue.

## Audio Direction

Each chant cycle should sound like a phrase building tension:

- Murmur: low soft syllables, quiet drone.
- Rising: higher pitch, faster shimmer.
- Release: clean bright cue, short opening tone.
- Success: phrase cuts off, bright chord resolves.
- Too early: muted pluck.
- Too late: spell snap or crackle.

Audio must leave room for VoiceOver. Avoid long spoken lines during the release window.

## Haptic Direction

- Murmur: none or very soft pulse.
- Rising: two light warning ticks.
- Release: crisp ready tick.
- Success: tight double pulse plus resonance snap.
- Too early: dull single thud.
- Too late: warning pulse.

## Copy Draft

Tutorial:

> Magic Tap is the two-finger double-tap shortcut. In this quest, it interrupts the enemy spell when the release cue appears.

Release cue:

> Release. Magic Tap now.

Success:

> Interrupted. The spell breaks.

Too early:

> Too early. Wait for the release cue.

Too late:

> Too late. The spell released.

L2 fake cue:

> False rise. Hold.

L3 intro:

> Interrupt as many releases as you can before the chorus ends.

## Implementation Tasks

### Phase 1: Spec and Routing

- Create `memlog/requirements/GameSpec-MagicTapBardsInterrupt.txt`.
- Define quest title, goal, prerequisites, level arc, scoring, and failure states.
- Decide whether this replaces a future quest slot or adds a new catalog item.
- Add or update GameCatalog definition once product slot is approved.
- Add localization key list to the spec before code begins.

Acceptance criteria:

- Spec explicitly states the gesture and the dedicated Magic Tap handler requirement.
- Spec includes L1/L2/L3 acceptance criteria.
- Spec names scoring thresholds and mistake rules.

### Phase 2: Interaction Architecture

- Identify the iOS API surface for Magic Tap handling in this app.
- Add a dedicated Magic Tap container or representable if SwiftUI alone is unreliable.
- Ensure the handler is active for the whole quest scene, not only a focused button.
- Log Magic Tap attempts with state: phase, timing offset, result.
- Add a debug state display that can be hidden for production.

Acceptance criteria:

- Magic Tap is received when VoiceOver focus is on objective text, scene art, timer, or status copy.
- One handler owns all Magic Tap decisions.
- Normal one-finger double-tap does not trigger the Magic Tap path.

### Phase 3: State Machine

- Define chant states: idle, murmur, rising, release, resolving, success, miss, timeout.
- Define per-level timing profiles.
- Use monotonic time for release window evaluation.
- Gate repeated Magic Tap attempts during resolving state.
- Add deterministic test hooks for fixed timing profiles.

Acceptance criteria:

- Early, valid, late, and duplicate attempts produce distinct results.
- State transitions are deterministic under test.
- L1 can be completed without timer pressure.
- L3 supports timeout and GameSession completion.

### Phase 4: ViewModel

- Create an observable quest ViewModel.
- Own level phase, chant state, mistakes, progress, timer, and result.
- Provide methods: startLevel, startChant, handleMagicTap, handleTimeout, continueLevel, retry.
- Emit semantic feedback events to `iOSQuestFeedbackCoordinator`.
- Announce state changes through a single VoiceOver announcement path.

Acceptance criteria:

- ViewModel is testable without SwiftUI rendering.
- No UI view computes game outcomes directly.
- Timer cancellation is handled on disappear/retry.

### Phase 5: SwiftUI Quest View

- Build the Bard's Interrupt quest surface.
- Keep the scene VoiceOver-first: objective, current chant status, timer when relevant.
- Avoid making the Magic Tap target look like a normal button.
- Add visible chant meter and enemy caster stage.
- Add continue/retry controls only outside active chant resolution.

Acceptance criteria:

- The active gameplay surface has a clear accessibility label and hint.
- Magic Tap instructions are visible and spoken in L1.
- Dynamic Type does not hide the chant state or continue/retry controls.
- The scene works in Lights Off mode if the quest will support it.

### Phase 6: Audio and Haptics

- Add or reuse semantic feedback intents for:
  - chant warning
  - release ready
  - interrupt success
  - too early
  - too late
  - level complete
- Map intents to iOS haptic/audio renderers.
- Ensure release cue is short and does not mask VoiceOver.

Acceptance criteria:

- Success, early, and late outcomes are distinguishable without sight.
- Audio/haptic cues respect user feedback settings.
- Repeated misses do not spam long cues.

### Phase 7: Localization

- Add all user-facing strings to `Localizable.xcstrings`.
- Include comments explaining gesture wording.
- Use "Magic Tap: two-finger double-tap" in first-run/tutorial copy.
- Avoid ambiguous "double tap" wording by itself.

Acceptance criteria:

- No hardcoded user-facing strings in quest code.
- Localization comments identify timing-sensitive strings.
- VoiceOver labels and hints are complete.

### Phase 8: Catalog, Hub, and Progression

- Add game definition to RA11yCore catalog if this becomes a shipped quest.
- Add hub card title, subtitle, and accessibility description.
- Decide unlock order relative to Banishment and Crystal Resonance.
- Add thumbnail/art placeholder if final art is not ready.

Acceptance criteria:

- Hub card can launch the quest through `pushGame`.
- VoiceOver gating still applies.
- Stored results appear on the hub card.

### Phase 9: Screenshot and QA Harness

- Add screenshot scene IDs for L1 tutorial, L2 fake cue, L3 timed, success, and timeout.
- Update screenshot route catalog.
- Update screenshot UI tests and Fastlane allowlist.
- Add deterministic launch args for chant state and progress.

Acceptance criteria:

- Screenshot contract validates.
- Screenshot states do not require real-time Magic Tap input.
- Captures show the visual cue differences clearly.

### Phase 10: Tests

- Unit test ViewModel timing windows.
- Unit test scoring thresholds.
- Unit test early/valid/late/duplicate Magic Tap outcomes.
- UI test launch/routing and static accessibility identifiers.
- Manual device test with VoiceOver for actual Magic Tap delivery.

Acceptance criteria:

- `utility/build_and_test.sh` passes.
- Device QA confirms two-finger double-tap triggers the handler.
- Simulator tests do not pretend to validate real Magic Tap delivery.

## Engineering Spikes

### Spike A: Magic Tap Delivery

Question: Does SwiftUI reliably receive Magic Tap for a full-screen quest surface?

Tasks:

- Create minimal local prototype or isolated quest surface.
- Test `accessibilityAction(.magicTap)` or equivalent SwiftUI path.
- If unreliable, test UIKit hosting/representable with `accessibilityPerformMagicTap`.
- Log handler invocation and focused element.

Decision output:

- Use SwiftUI-only handler, or
- Use UIKit bridge as the official Magic Tap substrate.

### Spike B: Focus Independence

Question: Can Magic Tap be received regardless of VoiceOver focus inside the scene?

Tasks:

- Put focus on objective card, scene art, status text, and controls.
- Perform Magic Tap from each focus location.
- Record which element receives the action.

Decision output:

- One full-screen accessibility element may need to own the scene during active chant, or
- A root UIKit container may need to implement the Magic Tap handler.

### Spike C: Timing Window Tuning

Question: What release window feels fair for a two-finger double-tap?

Initial guesses:

- L1 release window: 1600 ms.
- L2 release window: 1100 ms.
- L3 release window: 850 ms.
- Perfect window: centered 350 ms inside release.

Decision output:

- Confirm or adjust timing windows after device testing.

## Scoring Draft

L1:

- Completion only; no rank pressure.
- Mistakes are teaching moments.

L2:

- Complete after three successful interrupts.
- Mistakes tracked but no timer rank.

L3:

- 45 seconds.
- Legendary: clear with 0 mistakes.
- Adept: clear with 1-2 mistakes.
- Novice: clear with 3+ mistakes.
- Failed: timeout or too many unrecovered releases.

Potential bucket penalty:

- Every released enemy spell adds one mistake.
- Every early Magic Tap adds one mistake.
- Duplicate Magic Tap during resolving state does not add a mistake; it is ignored.

## Data Model Draft

Enums:

- `BardsInterruptPhase`: tutorial, decoyRhythm, timed, completed
- `ChantState`: idle, murmur, rising, release, resolving, interrupted, released
- `MagicTapOutcome`: tooEarly, interrupted, perfectInterrupt, tooLate, ignored
- `ChantProfile`: durations, releaseWindow, fakeCueCount, cueStyle

ViewModel state:

- current phase
- chant state
- chant started at
- release opened at
- release closes at
- successes
- mistakes
- time remaining
- status message
- last outcome
- completed result

## Risks

- Magic Tap may route to the focused VoiceOver element instead of the quest container.
- VoiceOver announcements can mask timing cues.
- Timing windows may feel unfair because two-finger double-tap has physical overhead.
- A visible fallback button could confuse the lesson.
- Too much rhythm-game complexity could obscure the accessibility skill.

## Mitigations

- Build Magic Tap delivery spike first.
- Keep L1 extremely forgiving.
- Use short release cue audio/haptic, not long spoken text during the action window.
- Make early/late feedback instructional.
- Add deterministic screenshot/test hooks, but require manual device QA for actual gesture delivery.

## Milestone Breakdown

### Milestone 1: Prototype Validated

- Magic Tap delivery spike complete.
- Full-screen handler chosen.
- Minimal Bard scene handles early/success/late.
- Device test confirms real Magic Tap works.

### Milestone 2: Playable L1

- Tutorial copy.
- One chant cycle.
- Success/early/late feedback.
- Continue to next phase.

### Milestone 3: Playable L2

- Fake cue.
- Three-interrupt completion.
- Mistake handling.
- Refined audio/haptics.

### Milestone 4: Playable L3

- Timer.
- GameSession integration.
- Ranking.
- Timeout/failure path.

### Milestone 5: Ship-Ready Integration

- Hub/catalog integration.
- Localization complete.
- Screenshot coverage.
- Unit and UI tests.
- Device QA checklist complete.

## Immediate Next Tasks

1. Decide quest slot and unlock order.
2. Run Spike A: Magic Tap Delivery.
3. Draft `GameSpec-MagicTapBardsInterrupt.txt`.
4. Choose visual direction: tavern stage, battlefield chorus, or arcane duel.
5. Define first timing profile and feedback intents.
