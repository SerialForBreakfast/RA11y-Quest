# ADR-0004: Arcanist's Tower as Rotor-Based Filtered Navigation

Date: 2026-04-22
Status: Proposed

## See also

- **ADR-0006** — VoiceOver **Actions** (default activate vs custom
  `accessibilityAction` names), copy without hard-coded default strings, and quest flow
  for **multi-action** elements.

## Context

RA11y needs a quest that teaches the VoiceOver rotor. Prior quests teach:

- Enchanter's Trial: one-finger swipe navigation and double-tap activation.
- Crystal Resonance: three-finger scrolling.
- Banishment: two-finger scrub / escape.

The rotor is a stronger and more abstract skill than those gestures. It is not a
single action with one visible outcome. It changes what subsequent swipes mean:
Headings jumps between headings, Links jumps between links, Adjustable changes
values, and other settings filter or transform navigation in different ways.

The original Arcanist's Tower draft proposed floors for Headings, Links,
Adjustable, and a mixed boss. That direction is pedagogically strong, but the
implementation must avoid one fragile assumption: the app should not try to
detect which rotor setting the user selected. Rotor state is platform-owned,
contextual, and not a stable game input surface.

## Decision

Implement The Arcanist's Tower as a rotor-based filtered-navigation quest with
three v1 disciplines:

- Headings: Codex floor.
- Links: Tome floor.
- Adjustable: Archery floor.

The game will not detect or punish rotor selection directly. Rotor mastery is
inferred from observable outcomes:

- The correct heading was activated.
- The correct link was activated.
- The draw weight was adjusted and fired at the correct value.
- The player completed the room within the time budget.
- The player avoided wrong activations or wrong shots.

Wrong rotor use naturally costs time because the player cannot efficiently reach
or adjust the required target. Feedback should describe the room outcome, not
accuse the player of choosing the wrong rotor.

## Core Interaction Model

The tower is a sequence of magical rooms. Each room has a semantic structure that
maps to one rotor setting.

1. The room presents a clear task and environmental cue.
2. The player invokes the VoiceOver rotor and chooses the useful setting.
3. The player uses normal VoiceOver swipes under that setting.
4. The player activates or adjusts the correct semantic element.
5. The room resolves as success, mistake, or timeout.

The rotor is the spell wheel. A room is not solved by finding a bespoke in-game
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

The Arcanist introduces the spell wheel and walks the player through one simple
Headings, Links, and Adjustable challenge. No rank.

### Stage 2: Trial

The Shifting Tower presents mixed rooms under a hard timer. The player infers the
needed rotor from room cues. Rank awarded.

### Stage 3: Lights Off

The same mixed-room model with reduced visuals. VoiceOver, haptics, and audio
carry the room identity. Rank awarded separately or as an advanced result.

## Lights Off Strategy

Lights Off should not change the semantic structure. The same heading, link, and
adjustable elements remain in the accessibility tree.

Visuals:

- Darkened tower.
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
- Success: tower chime / gate open.

Visuals:

- Room identity.
- Progress and timer.
- Thematic reward, not hidden information.

## Asset Generation Decision

Final art should wait until greybox rotor semantics pass device testing.

Asset families likely needed after greybox:

- Tower background.
- Arcanist portrait.
- Spell wheel diagram.
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
