# ADR-0008: Rotor Navigation — “Threefold Seal” Slim Composite v1

Date: 2026-05-01  
Status: Proposed  

## Related documents

- **ADR-0004** — Filtered navigation (Headings / Links / Adjustable); **wrong-action
  model** and no rotor-state detection remain authoritative for all navigation-rotor
  quests.
- **ADR-0006** — Rotor Actions (default vs custom actions); **out of scope** for this
  quest.
- **QuestConcept-ThreefoldSeal.txt** — Phase 0 one-pager and DesignProcess composite
  rationale.
- **RotorNavigationQuestBrainstorming.txt** — §10 shallow beats, §10.9 incorrect
  selections, §11 gamification framing.

## Context

The original deep-floor navigation-rotor draft (see **ADR-0004** and `GameSpec-ArcanistsTower.txt`
revision history) bundled **deep** practice for Headings, Links, and **Adjustable**, plus
Trial and Lights Off. Product direction now favors **one hub quest** with **one simple
beat each** for **Headings**, **Containers**, and **Links** only, under a single fiction
frame (“three seals”), with **Adjustable** and **Form controls** deferred.

This ADR records the **shipping interaction model** for that slim composite so
implementation, GameSpec, and mockups stay aligned.

## Decision

### 1. Quest shape

- **One** quest card; **three** sequential beats in Practice: **Headings** →
  **Containers** → **Links**.
- **Containers** is a **first-class** beat (not only Headings + Links).
- **Adjustable** is **not** in v1 of this quest.
- **Trial** (timed, ranked, cue-only) is **optional** for first ship; specify in
  GameSpec per milestone.
- **Lights Off** is **deferred** or post-clear unless cost is trivial.

### 2. Pedagogy and DesignProcess alignment

- **Single paradigm:** rotor changes what **horizontal navigation** visits.
- **Three proofs:** differ only by **which rotor setting** is the efficient tool; each
  beat is **shallow** (small target count, one success condition).
- Composite scope is **documented and product-approved** in QuestConcept Phase 0.

### 3. Accessibility and detection

- **Real semantics:** `.isHeader` (or equivalent) for title plates; container boundaries
  with meaningful **labels**; **link** trait for bound marks.
- **No** inspection of which rotor setting the user selected.
- **Scoring / mistakes** branch on **which element activated** (or timeout in Trial).

### 4. Wrong-action and copy

- Identical policy to **ADR-0004**: outcome-based lines; no “wrong rotor.”
- Operational detail: **RotorNavigationQuestBrainstorming.txt §10.9**.

### 5. Non-goals

- **Rotor Actions** (ADR-0006), **Form controls** beat, **Adjustable** beat in this
  quest’s v1.

## Consequences

### Positive

- Smaller build than three deep floors + Adjustable; clearer player expectation.
- Containers receives explicit teaching time (often omitted in generic “rotor” apps).

### Costs

- **Containers** authoring must be disciplined (labels, nesting); weak containers make
  the beat feel arbitrary.
- Composite still requires **three** semantic QA passes on device.

## Acceptance criteria

- GameSpec and implementation reference **ADR-0008** for v1 scope.
- Practice order is Headings → Containers → Links unless a playtest note in GameSpec
  documents a swap.
- Trial (if shipped) never names rotor settings in cues; ranks use `RankThresholds` for
  this game id.
- ADR-0004 remains the parent document for navigation-rotor philosophy; ADR-0008 does
  not relax wrong-action or rotor-detection rules.
