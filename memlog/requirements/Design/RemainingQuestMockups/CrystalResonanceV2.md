# Crystal Resonance v2 Mockup Brief

Status: Active refinement
Related: `memlog/research/ADR-0003-Dungeon-Resonance-Scroll-Interaction.md`,
`memlog/requirements/Design/DesignTicket-DungeonResonancePromptSheet.txt`

## Utility

Crystal Resonance should teach that three-finger scrolling is not merely moving
a list. It can reposition a world while VoiceOver focus remains stable. The
player learns to keep attention on a named scroll surface, move the environment,
listen for proximity, and activate only when alignment is true.

Real-world transfer:

- scrolling long pages without losing orientation,
- using a stable landmark while content moves,
- distinguishing focus movement from scroll movement,
- using sound/haptics to confirm position instead of relying only on sight.

## Screen Concept

The screen is a vertical dungeon shaft with a fixed crystal orb in the center.
The **Glyph stream** moves behind it. The Moonstone target and decoys drift in
the stream. The orb changes state as the Moonstone approaches alignment.

Visual hierarchy:

1. Top compact objective strip: "Align the Moonstone with the orb."
2. Center playfield: fixed orb + reticle, moving Glyph stream behind it.
3. Bottom status card: proximity state and action availability.
4. Primary action appears/enables only when locked: "Activate the Seal."

The orb and reticle are the player's anchor. They should never disappear,
including Lights Off.

## Text Wireframe

```text
┌────────────────────────────────────┐
│ Crystal Resonance                  │
│ Align the Moonstone with the orb.  │
├────────────────────────────────────┤
│                                    │
│        moving Glyph stream         │
│     ember shard       sun sigil    │
│                                    │
│             ┌────────┐             │
│             │  ORB   │  fixed      │
│             └────────┘             │
│                                    │
│          Moonstone approaching     │
│                                    │
├────────────────────────────────────┤
│ Almost aligned                     │
│ Three-finger scroll the stream.    │
│ [Activate the Seal] disabled       │
└────────────────────────────────────┘
```

## Stage States

### Prologue

Purpose: teach focus-versus-scroll.

Screen should show the orb, a short lesson card, and a practice Glyph stream.
The primary action stays disabled until the player performs one successful
three-finger scroll on the stream.

### First Attempt

Purpose: apply the scroll/alignment loop with no timer pressure.

The Moonstone starts visibly off-center. Decoys are present but quiet. The
status card announces:

- "Far - keep scrolling"
- "Getting warmer"
- "Almost aligned"
- "Aligned - seal it"

### Timed Trial

Purpose: apply the same mechanic under light pressure.

The timer belongs in a compact HUD, not inside the playfield. Timer announcements
must not overlap proximity announcements.

### Lights Off

Purpose: prove nonvisual play.

The surrounding stream darkens. Orb, reticle, target identity, and sound/haptic
proximity remain clear. The player can still complete the loop by listening and
scrolling.

## Accessibility Contract

- The Glyph stream has one clear accessibility label and hint.
- Decorative lane items are hidden unless they are the current target or
  actionable decoy.
- The orb status is spoken as state, not as a separate focus trap.
- Activation outside lock state is impossible or produces a short teaching cue.
- Reduce Motion keeps the alignment model understandable without constant motion.

## Screenshot Candidates

| Filename Idea | State | Purpose |
|---|---|---|
| `DungeonResonancePrologue` | practice stream + disabled begin action | proves the teaching screen |
| `DungeonResonanceApproach` | Moonstone near orb, action disabled | proves proximity feedback |
| `DungeonResonanceLocked` | Moonstone aligned, action enabled | proves success affordance |
| `DungeonResonanceLightsOff` | darkened stream, orb retained | proves nonvisual mode |

## Product Risk To Validate

The screen fails if the user thinks one-finger swiping should move the Moonstone.
The mockup must make "focus the stream, then three-finger scroll" unmistakable
without filling the screen with instructions.
