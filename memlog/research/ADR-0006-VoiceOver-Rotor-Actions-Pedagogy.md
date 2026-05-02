# ADR-0006: VoiceOver Rotor Actions — Default Activate vs Custom Actions

Date: 2026-04-29  
Status: Proposed  

## Related documents

- **ADR-0004** — Navigation-class **filtered navigation** (Headings / Links /
  Adjustable semantics).
- **ADR-0005** — Screenshot / pedagogy validation when scenes exist.
- **memlog/research/AccessibilityFeatureGamification.md** — Broader VoiceOver teaching
  map.
- **RA11y-iOS/RA11y-iOS/Hub/iOSHubView.swift** — SwiftUI `.accessibilityRotor`
  (“Quests”). That API adds **custom rotor entries** for focus jumps; it is **not**
  the same as the system **Actions** list on a focused element (see **Not in scope**
  below).

## Context

### What “Rotor Actions” means here

**Rotor Actions** means the VoiceOver flow where the user opens the **Actions** entry
in the **Rotor**, then (per platform UX) moves among **actions attached to the
currently focused element** — the **default activate** behavior and **custom
accessibility actions** — so **double-tap** runs the **selected** action, not an
unintended custom one.

On iOS with VoiceOver, many controls expose a **single** obvious double-tap: activate.
When developers add **`accessibilityAction`** / **`UIAccessibilityCustomAction`**
(and equivalents), the focused element can expose **multiple** actions. The user must
learn to:

1. Open the **Rotor** and select the **Actions** setting (wording may vary slightly by
   OS / locale).
2. **Swipe** (VoiceOver’s action-navigation gesture on the focused element) to move
   the selection among **Default** / **Activate** (system-presented) and **named
   custom** actions.
3. **Double-tap** to run the **currently selected** action.

**Pedagogical goal for the quest this ADR informs:** the player reliably **selects
the intended action** — including the **default activate** when the puzzle requires
it — among one or more **custom** actions: **multi-action focus management** as its own
skill, distinct from filtered linear navigation (Headings, Links, and similar).

### Platform constraint (non-negotiable UX input)

When custom actions are present, VoiceOver still exposes a **default / primary
activate** concept. Its **human-readable label and exact phrasing** are **owned by
the system** (and can differ by **language**, **OS version**, and **element type**).
The app **cannot** set that string to quest-themed copy (for example “Cast simple
cantrip” instead of whatever the system uses).

**UX consequence:** RA11y must **teach the gesture pattern and listening strategy**,
not a **verbatim** string the learner might search for forever. Example teaching line
shape: “In **Actions**, swipe until VoiceOver reads the **ordinary activate** line —
the one that means open or confirm, not a named spell — then double-tap.” Product
and localization still vet tone; we never assert a fixed English string as canonical.

### Terminology: three “rotor” surfaces

“Rotor” is overloaded in speech, in VoiceOver, and in SwiftUI APIs. For clarity:

| Idea | Role |
| --- | --- |
| **Navigation rotor settings** | Change what **flick next/previous** visits (headings, links, …). |
| **Actions (rotor)** | Change what **double-tap does** on **this** focus target. |
| **App `accessibilityRotor` entries** | Developer-defined **shortcuts** (e.g. hub Quests) in the rotor menu. |

This ADR drives design for the **Actions** row unless a GameSpec explicitly combines it
with another surface in one quest.

## Decision

### 1. Primary pedagogy for a “Rotor Actions” quest

- **Primary:** Use the **Actions** rotor setting to move selection among **default
  activate** and **custom** actions, then double-tap the correct one for the beat.
- **Custom action names** are **fully authorable** — use clear, distinct names so
  listening differentiates them from the default slot.
- **Default slot** is taught by **position / role description**, never as a single
  hard-coded label string in mandatory progression copy.

### 2. Informing the user about reaching the default action

**Must include** in practice (and optionally a one-line reminder in trial):

- That **Actions** appears in the **same Rotor** control they use for other settings.
- That when several actions exist, **double-tap uses whichever action is currently
  selected** in Actions — so they must **open Actions** and **swipe** until the
  desired behavior is selected before double-tapping.
- That the **default / ordinary activate** line **may not match visible on-screen
  text** and **may read differently** after an OS update — **rely on the pattern**,
  not memorized wording.

### 3. Feedback and detection

- **Do not** coach navigation-rotor selection (“switch to Headings”) — off-topic for a
  Rotor Actions beat.
- **Do** frame mistakes as **outcomes**: wrong spell, wrong door, trap sprung, etc.,
  after the user’s **activated** action fires (game observes **which handler ran** or
  equivalent). Do **not** infer **navigation** rotor setting from the platform; **do**
  branch on **which accessibility action ran** (app-owned handlers).

**Cross-reference ADR-0004:** that ADR rejects inspecting **navigation rotor** choice for
its quest model. For a Rotor Actions quest, observing **which accessibility action
executed** is appropriate and is the natural way to score a beat.

### 4. Curriculum placement (explicitly open)

Any of the following is valid product work; **pick one in a GameSpec / ticket**, not
in this ADR alone:

- **Dedicated quest** — “Rotor Actions” module that only teaches Actions.
- **Floor inside** a larger tower — only if combined with ADR-0004 navigation floors
  with a **clear** cognitive separator (different beat, different VO script).
- **Short module** in First Run or hub help — shallow pass before a timed quest.

Until that choice is locked, implementation should treat **ADR-0004** and **ADR-0006**
as **parallel** specs for **different skills**.

### 5. No hint affordances

The Rotor and **Actions** model are already unfamiliar; switching among **default
activate** and **custom** actions is the full interaction budget for this quest.

- **Do not** add hint buttons, hint links, on-demand “stuck” lines that repeat the
  gesture recipe, hint-specific rotor entries, or other **auxiliary hint** focus
  targets.
- **Practice** carries explicit teaching (scripted copy and beats); **Trial** uses
  environmental cues, outcome feedback, and **retry** — not a parallel hint channel.

## Player flow (template — quest shell TBD)

Sections below describe **intent**; exact fantasy framing, ranks, and unlock order
belong in a GameSpec once placement is chosen.

### Entry

- Hub card or sub-route; VoiceOver required per existing product rules.

### Stage 1 — Practice (may name “Actions” explicitly)

1. **Single-action control** — Baseline: focus, double-tap, success. No custom actions.
2. **Two named custom actions + default** — Teach: Rotor → **Actions** → swipe until
   the **ordinary activate** (describe without fixed string) is selected →
   double-tap to complete a **default** objective.
3. **Same stack, different beat** — Objective requires a **specific named custom
   action**; player must swipe to that line, then double-tap.
4. **Distractor density** — Three or more custom actions; only one correct; wrong
   custom fires **outcome** feedback.

### Stage 2 — Trial

- Timer / rank optional.
- **Do not** read the solution as “pick Default”; use **environmental** cues (which
  door opens, which rune glows in VO description, etc.).
- Player must infer that the **mechanism** is always **Actions + swipe + double-tap**.

### Stage 3 — Lights Off (optional)

- Same **multi-action** elements and labels; visuals reduced; audio/haptics carry
  identity per existing Lights Off guidance elsewhere.

### Exit

- Results; hub return; replay for rank if applicable.

## VoiceOver and copy rules

### Practice

- May say **“Actions”** by name as a rotor setting.
- Explain **default vs custom** using **behavior** and **custom action names we
  author**; never require the learner to memorize Apple’s default line verbatim.

### Trial / Lights Off

- No “you selected the wrong rotor line” **by system string**.
- Outcome-based lines only (“That glyph was a ward, not a key.”).

## UI and accessibility tree (requirements)

- **Multi-action beats** use **one focus target** with **default activate** plus
  **`accessibilityAction`** (or platform equivalent) for each custom action the design
  needs.
- **Custom actions** get **unique, short, VO-friendly names** (localized).
- **No extra focus targets** for hints or “remind me” affordances — narrative or
  objective copy belongs in **non-interactive** chrome or scripted **Practice** only
  (see **No hint affordances** in Decision above).
- **Decorative** art: `accessibilityHidden` / hidden from accessibility as usual.

## Rotor interaction matrix (this ADR only)

| User intent | Where in VoiceOver | Then |
| --- | --- | --- |
| Run the **ordinary** open/confirm on this element | Rotor → **Actions** → swipe until **default activate** is selected | Double-tap |
| Run a **named** custom behavior on this element | Rotor → **Actions** → swipe until that **custom name** is selected | Double-tap |
| Jump between **headings** on the screen | Rotor → **Headings** (navigation) | **Out of scope for this ADR** |
| Use hub **Quests** shortcut | Rotor → **Quests** (app-defined entry) | **Out of scope for this ADR** |

## Not in scope (brief pointers only)

- **Navigation rotor** curricula — **ADR-0004** and future specs.
- **SwiftUI `accessibilityRotor`** authoring patterns — hub implementation; different
  problem (menu entries that **move focus**, not action stack on one node).

## Consequences

### Positive

- Aligns a future quest with a **real** iOS pain point (multi-action controls).
- Teaching respects **non-customizable** default action labels.
- Scoped spec so **navigation rotors** and **Rotor Actions** are not conflated in one
  lesson without an explicit GameSpec merge.

### Costs

- **Dense** lesson: easy to overload if combined with navigation-rotor floors in the
  same timed session without design discipline.
- **No hint channel** means stuck players rely on Practice clarity, trial cues, and
  retry — acceptable tradeoff to keep cognitive load bounded.
- **Device testing** mandatory; UI tests cannot fully verify Rotor Actions behavior.

## Open questions

1. **Quest identity** — Name, art, and whether this ships as its own `GameKind` or as
   a chapter inside another quest.
2. **Unlock order** — Where it sits relative to Enchanter / Resonance / Banishment /
   ADR-0004 tower.
3. **Maximum custom actions** per beat for cognitive cap (three? five?).
4. **Magic Tap** — Whether any beat uses Magic Tap as an alternate **action** in the
   same stack (complexity warning).
5. **Screenshot contract** — Scene IDs and anchors when UI exists (**ADR-0005**).

## Acceptance criteria

- Product and engineering can tell a **filtered-navigation** quest (e.g. ADR-0004) from
  a **Rotor Actions** quest (this ADR) without ambiguity.
- Practice copy **explicitly** teaches using the **Actions** rotor setting to reach
  **default activate** among custom actions, **without** relying on a fixed default
  string.
- Trial scoring keys off **which action ran** (or equivalent observable), not off
  inferred navigation-rotor setting.
- GameSpec / tickets that implement a Rotor Actions quest **reference this ADR** and
  declare curriculum placement (standalone vs combined).
- **No hint affordances** — no hint buttons, on-demand gesture-recipe reminders, or
  extra focus targets for “stuck” help (Decision: **No hint affordances**).
