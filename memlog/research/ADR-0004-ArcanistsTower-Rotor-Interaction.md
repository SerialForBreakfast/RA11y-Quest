# ADR-0004: Arcanist's Tower as Rotor-Based Filtered Navigation

*Player-facing v1 quest name: **The Threefold Seal** — see **ADR-0008**.*

Date: 2026-04-22
Status: Proposed

> **Naming (2026-05):** The shipped navigation-rotor quest is **The Threefold Seal** (**ADR-0008**, QuestConcept-ThreefoldSeal). This ADR keeps the historical filename and much of the **early “wizard tower / floors” draft** for context; do **not** treat that fiction as current player-facing copy. **Wrong-action policy** and **no rotor-state detection** remain authoritative for **The Threefold Seal** and any future navigation-rotor quests.

## See also

- **ADR-0006** — VoiceOver **Actions** (default activate vs custom
  `accessibilityAction` names), copy without hard-coded default strings, and quest flow
  for **multi-action** elements.
- **ADR-0008** — Slim composite v1: one quest, shallow beats for **Headings →
  Containers → Links** (Threefold Seal); defers Adjustable and deep tower floors.

## Context

RA11y needs a quest that teaches the VoiceOver rotor. Prior quests teach:

- Enchanter's Trial: one-finger swipe navigation and double-tap activation.
- Crystal Resonance: three-finger scrolling.
- Banishment: two-finger scrub / escape.

The rotor is a stronger and more abstract skill than those gestures. It is not a
single action with one visible outcome. It changes what subsequent swipes mean:
Headings jumps between headings, Links jumps between links, Adjustable changes
values, and other settings filter or transform navigation in different ways.

The original deep-floor draft proposed themed rooms for Headings, Links,
Adjustable, and a mixed boss. That direction is pedagogically rich, but the
implementation must avoid one fragile assumption: the app should not try to
detect which rotor setting the user selected. Rotor state is platform-owned,
contextual, and not a stable game input surface.

## Decision

**Shipping v1 (The Threefold Seal — ADR-0008):** Implement **one** hub quest with **three shallow beats** — **Headings**, **Containers**, **Links** — under archive / seal fiction. **Adjustable** and deep multi-floor scope are **deferred** from v1.

**Early draft (historical — not v1 ship list):** The same wrong-action and detection rules applied to a taller “floor” concept:

- Headings: codex-style title plates.
- Links: margin / tome-style link targets.
- Adjustable: value-based challenge (archery metaphor in old notes).

The game will not detect or punish rotor selection directly. Mastery is
inferred from observable outcomes (which element activated, timeouts, mistake counts) — see ADR-0008 for the slim beat list.

Wrong rotor use naturally costs time because the player cannot efficiently reach
the required target. Feedback should describe the **archive / beat** outcome, not
accuse the player of choosing the wrong rotor.

## Core Interaction Model

Each **beat** presents a semantic structure that rewards one navigation-class rotor setting.

1. The beat presents a clear task and environmental cue.
2. The player invokes the VoiceOver rotor and chooses the useful setting.
3. The player uses normal VoiceOver swipes under that setting.
4. The player activates the correct semantic element (heading, container region, or link).
5. The beat resolves as success, mistake, or timeout.

The rotor is the platform’s **navigation mode picker**. A beat is not solved by finding a bespoke in-game
button; it is solved by using the platform's semantic navigation model.

## Accessibility Model

### Headings

- Chapter titles must be real accessibility headings.
- Body text remains accessible so the value of the Headings rotor is clear.
- The target chapter is activatable.
- Wrong chapter activation is observable and counted as a mistake.

### Links

- Rune targets must be real links or link-trait elements.
- Surrounding prose remains accessible so the Links rotor has practical value.
- Wrong rune activation is observable and counted as a mistake.

### Adjustable

- Draw weight must expose native adjustable behavior.
- VoiceOver should announce value changes through the platform's adjustable value
  model.
- Firing at the wrong value is observable and counted as a mistake.

### Focus

- On room entry, focus should land on the objective/status region.
- During active play, avoid fighting the user's rotor navigation with repeated
  programmatic focus changes.
- Decorative art remains hidden from accessibility.

## Wrong-Action Model

The game does not inspect rotor choice.

Observable mistake events:

- Wrong heading activated.
- Wrong link activated.
- Arrow fired under or over the required draw value.
- Timer expires.

Non-events:

- Selecting the wrong rotor.
- Swiping inefficiently.
- Taking time to explore.

Instructional feedback should be framed around the room:

- "That is not the chapter."
- "That rune is a trap."
- "The arrow falls short. Draw more."
- "Too much force. Ease the draw."

Avoid:

- "Wrong rotor."
- "You chose Links."
- "Switch to Headings."

The trial stage should withhold explicit setting names, but practice can name the
setting while teaching.

## Stage Structure

The original floor fantasy is folded into RA11y's three-stage structure.

### Stage 1: Practice

Lesson copy introduces the rotor and walks the player through the **Threefold Seal** shallow beats (see ADR-0008). No rank in Practice.

### Stage 2: Trial

The timed **trial** presents mixed beats under a hard timer. The player infers the
needed rotor from room cues. Rank awarded.

### Stage 3: Lights Off

The same mixed-room model with reduced visuals. VoiceOver, haptics, and audio
carry the room identity. Rank awarded separately or as an advanced result.

## Lights Off Strategy

Lights Off should not change the semantic structure. The same heading, link, and
adjustable elements remain in the accessibility tree.

Visuals:

- Darkened scene / minimal chrome.
- Minimal room anchor.
- No reliance on visible text/rune glow/bow meter alone.

Feedback:

- VoiceOver announces room cue and target.
- Audio gives each discipline a short identity cue.
- Haptics mark success, mistake, and timer pressure.

## Feedback Roles

VoiceOver:

- Objective.
- Room cue.
- Target labels and values through native semantics.
- Success/mistake/timeout announcements.

Haptics:

- Room shift.
- Mistake.
- Correct activation.
- Exact adjustable hit.

Audio:

- Codex: page turn / parchment.
- Tome: rune chime.
- Archery: bowstring tension.
- Success: short seal / gate-open cue.

Visuals:

- Room identity.
- Progress and timer.
- Thematic reward, not hidden information.

## Asset Generation Decision

Final art should wait until greybox rotor semantics pass device testing.

Asset families likely needed after greybox:

- Quest backdrop (archive / seal tone).
- Narrator or symbolic portrait (optional).
- Rotor gesture diagram.
- Codex room.
- Tome room.
- Archery room.
- Bow and target lock.
- Success flare.
- Lights Off anchor.

Art must not replace semantic elements. Headings, links, and adjustable controls
must remain real accessibility elements.

## Consequences

Positive:

- Teaches real rotor behavior instead of a fake game-only shortcut.
- Avoids brittle or impossible rotor-state detection.
- Lets time and mistakes reflect actual rotor mastery.
- Keeps the boss/trial replayable through randomized semantic room types.

Costs:

- Device VoiceOver testing is mandatory for each rotor discipline.
- UI tests cannot fully validate rotor behavior.
- The game must be designed so inefficient navigation costs time naturally.
- Adjustable may require careful implementation to expose native behavior and a
  separate fire action cleanly.

## Acceptance Criteria

- The ADR explicitly rejects direct wrong-rotor detection.
- Each v1 discipline maps to real VoiceOver semantics.
- Practice names the rotor setting; Trial and Lights Off rely on room cues.
- Wrong-action feedback describes observable room outcomes.
- Final implementation is not approved until device testing confirms:
  - Headings rotor reaches chapter titles.
  - Links rotor reaches rune links.
  - Adjustable rotor changes draw weight.
  - The quest remains completable with VoiceOver.
