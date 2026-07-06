# The Threefold Seal Mockup Brief

Status: Confirmed future quest
Related: `memlog/requirements/GameSpec-ArcanistsTower.txt`,
`memlog/research/ADR-0008-Rotor-Navigation-ThreefoldSeal-SlimV1.md`

## Utility

The Threefold Seal should teach the highest-leverage VoiceOver navigation habit
that remains after the earlier quests: use the rotor to choose what next/previous
flicks move through.

Real-world transfer:

- jumping by headings in articles and settings screens,
- moving between major containers or regions,
- scanning links without reading every word,
- choosing navigation mode intentionally instead of swiping linearly forever.

The quest must not test whether the app can detect the selected rotor setting.
It should detect which element the player activates.

## Screen Concept

The player stands before an archive door with three seal rings. Each ring opens
through one shallow beat:

1. **Title plates**: use Headings to find the named chapter.
2. **Storage niches**: use Containers to jump between labeled regions.
3. **Bound marks**: use Links to find the named mark.

The same screen shell should persist across beats so the player understands the
single paradigm: twist rotor, then flick between that kind of thing.

## Text Wireframe

```text
┌────────────────────────────────────┐
│ The Threefold Seal                 │
│ Seal 1 of 3: Find the title plate. │
├────────────────────────────────────┤
│ Door Rings: ● ○ ○                  │
├────────────────────────────────────┤
│ Title Hall                         │
│                                    │
│  Heading: Moonlit Ledger           │
│  body text paragraph               │
│                                    │
│  Heading: Ember Contract           │
│  body text paragraph               │
│                                    │
│  Heading: Silent Key               │
│  body text paragraph               │
├────────────────────────────────────┤
│ Hint: Set rotor to Headings, then  │
│ flick to Silent Key.               │
└────────────────────────────────────┘
```

## Beat Mockups

### Beat A: Title Plates

Visual: a vertical archive page with 4-6 large title plates and short body text
between them.

VoiceOver purpose: the title plates are real headings. Body text remains
readable but intentionally inefficient to traverse linearly.

Player action: activate the named title plate.

### Beat B: Storage Niches

Visual: three large labeled vault niches in a row or stacked cards:

- Brass Niche
- Frost Niche
- Shadow Niche

VoiceOver purpose: each niche is a labeled container/region with a clear open
action. Color alone never identifies the target.

Player action: open the named niche.

### Beat C: Bound Marks

Visual: a manuscript page with short prose and 3-4 margin marks that behave as
links.

VoiceOver purpose: the bound marks are real links. Prose is readable but not the
efficient path.

Player action: activate the named bound mark.

## Accessibility Contract

- Practice may name "Headings", "Containers", and "Links" once per beat.
- Trial cues should describe the environment without naming the rotor setting.
- Wrong activation copy must be outcome-based, not "wrong rotor."
- All beat targets must be semantically real: heading, container, or link.
- Mistake cooldown prevents repeated accidental activations from flooding speech.

## Screenshot Candidates

| Filename Idea | State | Purpose |
|---|---|---|
| `ThreefoldSealPrologue` | door + three rings + rotor lesson | proves overall lesson |
| `ThreefoldSealHeadings` | title plate beat | proves heading navigation target |
| `ThreefoldSealContainers` | storage niche beat | proves container navigation target |
| `ThreefoldSealLinks` | bound mark beat | proves link navigation target |
| `ThreefoldSealResult` | all three seals lit | proves completion |

## Product Risk To Validate

The quest fails if it feels like three unrelated minigames. The shared door,
ring progress, and repeated "rotor changes what flicks visit" framing must make
the three beats feel like one transferable navigation lesson.
