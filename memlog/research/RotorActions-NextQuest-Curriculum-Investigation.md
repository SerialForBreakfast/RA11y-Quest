# Investigation: “Next quest” for Rotor Actions — curriculum gap and improvement paths

Date: 2026-05-01  
Status: Draft  

## Question

Is the planned next rotor-related quest a good way to teach **Rotor Actions** (VoiceOver
**Actions** on a focused element: default activate vs custom `accessibilityAction`s),
and how should we improve it?

## Findings

### 1. Shipped catalog includes navigation rotor (The Threefold Seal) but not Rotor Actions

`GameCatalog` includes **The Threefold Seal** (`GameKind.arcanistsTower`, id `arcanists-tower`) after **The Banishment**. There is still **no** dedicated **Rotor Actions** quest (**ADR-0006**) in the hub until product ships that spec.

### 2. The navigation rotor quest is a different skill from Rotor Actions

**The Threefold Seal** (see `memlog/requirements/GameSpec-ArcanistsTower.txt`, **ADR-0008**, **ADR-0004** wrong-action model) teaches **navigation-class** rotor settings in v1:

- **Headings** → jump between headings  
- **Containers** → jump between labeled regions  
- **Links** → jump between links  

That is **filtered linear navigation**: what **next/previous flick** visits.

Historical brainstorming for a deeper rotor curriculum lives in `memlog/research/ArcanistsTower.txt` (retained for archive tone only; **not** the v1 ship list).

**Rotor Actions** (**ADR-0006**) is **not** that. It is: Rotor → **Actions** → swipe
among actions on the **same** focus target → double-tap the one you mean (system
default vs named customs).

So if the product goal is “the next quest teaches **Rotor Actions**,” the **Threefold Seal** navigation quest is **misaligned as the vehicle** for that goal. It remains the right hub card for **navigation rotor** literacy — and must **not** be mistaken for the ADR-0006 quest without a major respec.

### 3. Why a conflated design would feel weak

If one quest tries to teach **both** navigation rotors and **Actions** in one timed
flow:

- Cognitive load stacks (spell wheel vs action stack; two meanings of “rotor”).
- **ADR-0006** explicitly avoids hint affordances; **GameSpec-ArcanistsTower** practice
  still calls for **explicit setting names and hints** — appropriate for **navigation**
  practice, not a drop-in match for a minimal Rotor Actions quest.
- Risk of copy that sounds like “rotor” without distinguishing **Headings** from
  **Actions** in the VoiceOver menu.

### 4. What would make a **good** Rotor Actions next quest (high level)

Aligned with **ADR-0006**:

- **One primary multi-action focus target** per beat; **2–4** actions total early.
- **Custom action names** short, parallel, VO-distinct (e.g. neutral vs empowered vs
  damped, or track-switch verbs).
- **Practice** names **Actions** and teaches default vs custom **by behavior**, not
  Apple’s exact default string.
- **Trial** uses **environmental** cues only; scoring uses **which action ran**.
- **No** separate hint UI; retry + outcome feedback only.

Thematic wrappers discussed separately (e.g. **rail switcher**, **seal with multiple
rites**) are compatible if they map to **one console** and **finite verbs**.

## Improvement paths (choose explicitly in product)

| Path | Description |
| --- | --- |
| **A. Split curriculum** | Ship **The Threefold Seal** as the **navigation rotor** quest (ADR-0008 / ADR-0004 policy). Ship a **second**, smaller quest (or chapter) for **Rotor Actions** (ADR-0006). Hub order and names make the distinction obvious. |
| **B. Rotor Actions first** | If multi-action controls are the higher pain point for your audience, prioritize a **dedicated** Rotor Actions quest **before** or **after** the navigation quest, but **not** merged into the same lesson card copy. |
| **C. Respec combined quest** | Fold Actions into the same card **only** with strict separation: separate stages, no shared “rotor menu” copy that conflates **Headings** with **Actions**, device-validated pacing. Highest writing and UX risk. |

Recommendation for clarity: **Path A** unless playtesting proves a combined single-card quest is
worth the complexity.

## Concrete doc / engineering follow-ups

1. **GameSpec-ArcanistsTower.txt** — Add a one-line **scope note** at the top: this game
   teaches **navigation rotor settings**, not **ADR-0006** Rotor Actions; link ADR-0006.
2. **New GameSpec** (when ready) — `GameSpec-RotorActions` (working title) referencing
   only ADR-0006 mechanics and rank model.
3. **Implementation** — New `GameKind`, hub row, VO gate, and views when product picks
   Path A or B.

## References

- `memlog/research/ADR-0004-ArcanistsTower-Rotor-Interaction.md`
- `memlog/research/ADR-0008-Rotor-Navigation-ThreefoldSeal-SlimV1.md`
- `memlog/research/ADR-0006-VoiceOver-Rotor-Actions-Pedagogy.md`
- `memlog/requirements/GameSpec-ArcanistsTower.txt`
- `memlog/research/ArcanistsTower.txt`
- `RA11yCore/Sources/RA11yCore/GameCatalog/GameDefinition.swift` (current catalog end
  state as of investigation date)
