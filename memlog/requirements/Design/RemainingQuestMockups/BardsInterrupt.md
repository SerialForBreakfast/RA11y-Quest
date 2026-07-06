# Bard's Interrupt Mockup Brief

Status: Conditional research
Related: `memlog/MagicTap-BardsInterrupt-Tasks.md`,
`memlog/requirements/GameSpec-MagicTapFirstSpell.txt`

## Utility

Bard's Interrupt should proceed only if it teaches more than First Spell. First
Spell introduces Magic Tap as a simple two-finger double-tap. Bard's Interrupt
would need to teach the next layer: Magic Tap can be a context-sensitive shortcut
whose meaning depends on what the current app is doing, not on which button has
focus.

Real-world transfer:

- starting/stopping media,
- answering/ending calls,
- pausing speech or an active interaction,
- understanding that Magic Tap is app-contextual and not always a focused
  control activation.

If the quest becomes mostly a timing game, park it.

## Screen Concept

The player faces a stage or tavern threshold where an enemy caster performs a
chant. The active surface is not a button. The whole scene listens for Magic Tap.

The chant has three readable states:

1. Murmur: spell forming, too early.
2. Rising: warning, prepare.
3. Release: interrupt now.

The visual should make timing clear without relying only on color.

## Text Wireframe

```text
┌────────────────────────────────────┐
│ Bard's Interrupt                   │
│ Wait for Release. Magic Tap then.  │
├────────────────────────────────────┤
│                                    │
│       enemy caster silhouette      │
│          chant ring opening        │
│                                    │
│  Murmur ── Rising ── RELEASE       │
│                      ^ now         │
│                                    │
│       bard strings glowing         │
├────────────────────────────────────┤
│ Release. Magic Tap now.            │
│ No button target required.         │
└────────────────────────────────────┘
```

## Stage States

### Tutorial Interrupt

Purpose: teach the gesture and release cue.

The release window is generous. The scene says both "Magic Tap" and
"two-finger double-tap." One successful interrupt clears the stage.

### Decoy Rhythm

Purpose: teach restraint.

The caster produces a false rise before the real release. The false rise should
look and sound different from Release by shape, motion, and audio/haptic texture,
not just color.

### Timed Performance

Purpose: prove contextual Magic Tap under light pressure.

The player interrupts several release windows before a short timer expires.
Timer speech must never cover the release cue.

## Accessibility Contract

- The active gameplay scene has a clear label and hint.
- VoiceOver focus location should not determine whether Magic Tap works.
- A normal focused-button double-tap should not be mistaken for Magic Tap.
- Early, correct, late, and duplicate Magic Tap attempts produce distinct
  feedback events.
- Release cue must be short enough that the player can act immediately.

## Screenshot Candidates

| Filename Idea | State | Purpose |
|---|---|---|
| `BardsInterruptPrologue` | Magic Tap lesson | proves additional value beyond First Spell |
| `BardsInterruptRising` | warning state | proves preparation cue |
| `BardsInterruptRelease` | interrupt window | proves clear action timing |
| `BardsInterruptDecoy` | false rise | proves restraint teaching |
| `BardsInterruptResult` | interrupted spell | proves completion |

## Product Risk To Validate

The quest fails if users read it as "press the glowing thing." It must feel like
the app itself is in a temporary state where Magic Tap has contextual meaning.
