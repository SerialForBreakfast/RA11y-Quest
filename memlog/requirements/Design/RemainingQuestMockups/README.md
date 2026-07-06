# Remaining Quest Mockups

Date: 2026-07-04

This folder groups early mockup briefs for quests that are not yet fully settled
or not yet shipped as final product experiences. These are implementation-facing
textual mockups: they define the screen shape, accessibility utility, stage
sequence, screenshot candidates, and product risk before any authored PNG mockup
or final asset prompt session.

## Design Goal

Each remaining quest should preserve the utility of the earlier completed quests:

- **First Spell** proves a gesture can be introduced gently before gameplay.
- **Enchanter** proves one-finger VoiceOver navigation and activation can become
  a readable target-selection game.
- **Crystal Resonance** proves gesture-focused training can teach scroll as a
  real spatial action, not just a list operation.
- **Banishment** proves escape/scrub can be taught as a recovery affordance under
  pressure.

Future quests should carry that same practical value: each screen should look
like a fantasy quest, but the trained skill must map directly to real Apple UI
workflows.

## Mockup Set

| Quest | Status | Primary Utility | Mockup Brief |
|---|---|---|---|
| Crystal Resonance v2 | Active refinement | Three-finger scroll for spatial alignment and nonvisual guidance | `CrystalResonanceV2.md` |
| The Threefold Seal | Confirmed future quest | Rotor navigation through headings, containers, and links | `ThreefoldSeal.md` |
| Bard's Interrupt | Conditional research | Magic Tap as a context-sensitive global shortcut | `BardsInterrupt.md` |

## Shared Mockup Standards

- Start with the actual usable quest screen, not a marketing screen.
- Keep the first viewport legible on iPhone small, iPhone large, and iPad.
- Give every gameplay surface one obvious accessibility purpose.
- Make the trained VoiceOver gesture visible, spoken, and mechanically necessary.
- Keep fiction and mechanics aligned: the fantasy object should explain the
  accessibility skill, not obscure it.
- Define pass/fail screenshot states early so fastlane coverage has a target.

## Open Product Questions

- Should Crystal Resonance v2 replace the current Dungeon/Crystal flow fully, or
  ship as a phased refinement?
- Should Threefold Seal v1 ship Practice only, or include a ranked Trial?
- Should Bard's Interrupt proceed after First Spell, or remain parked unless it
  proves additional Magic Tap transfer value?
