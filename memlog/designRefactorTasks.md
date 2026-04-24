# Design & Copy Refactor Tasks
Date: 2026-04-22
Related: Crystal Resonance (Dungeon Descent), all quests

---

## Context

Two goals:
1. **Rename the scroll zone** — "Moonstone alignment lane" is thematically wrong and mechanically confusing. Replace with **"Glyph stream"** everywhere.
2. **Tighten all copy** — objective cards, VO scroll status, hints, feedback, and flavor text are verbose, redundant, or misdirected. Instructions belong in the gesture tip / hint system, not in the objective or VO status strings.

**Primary edits:** `Localizable.xcstrings`. **Also update** comments and canonical terminology docs that still say “Moonstone alignment lane,” or engineering/onboarding will drift from shipped copy (see **Scope — beyond xcstrings** at the end).

---

## Task 1 — Rename the scroll zone to "Glyph Stream"

**Why:** "Lane" has no thematic fit. "Glyph stream" describes what the player experiences (glyphs flowing past as they scroll) and implies the interaction (you scroll the stream). Instructions referencing the zone by name must all update together or VoiceOver announces the wrong label.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.a11y.scroll.container` → `"Glyph stream"`
- [ ] `dungeon.a11y.scroll.container.hint` → `"Three-finger scroll to move the stream."`
- [ ] `dungeon.resonance.tip.voFocusOnLane` → `"Nothing moving? Swipe to 'Glyph stream' first."`
- [ ] `dungeon.explain.gesture.swipe3` → `"Three fingers: scroll the glyph stream"`
- [ ] `dungeon.explain.practice_tip` → `"Three-finger scroll the glyph stream to practice."`
- [ ] `dungeon.explain.narration` → `"Scroll the glyph stream with three fingers. Align the Moonstone with the orb to seal it."`
- [ ] `dungeon.a11y.explain.lesson` → `"One finger moves focus. Three fingers scroll the glyph stream. Align the Moonstone with the orb."`
- [ ] `voSpell.threeFinger.body` → `"On the glyph stream, three-finger scroll up or down moves the stream."`
- [ ] `voSpell.kicker.scrolling` → e.g. `"Glyph stream"` (drop **Shaft scroll** if the new name is canonical)
- [ ] `voSpell.threeFinger.*` — sweep for “lane” / “alignment lane”; match **Glyph stream**
- [ ] `game.scrollHunt.goal`, `result.skillTransfer.scrollHunt.*`, `basicsSequence.skill.scrollHunt.intro` if they still say “Moonstone lane” / “alignment lane”
- [ ] `dungeon.resonance.hint` → `"Scroll the glyph stream until the Moonstone aligns, then Activate the Seal."`

**Verify:** VoiceOver on → swipe right through elements on L1 → hear "Glyph stream" as the zone label. Confirm the gesture tip card and hint text both say "glyph stream."

---

## Task 2 — Trim objective strings (visual + VoiceOver)

**Why:** Objective cards currently embed gesture instructions. Those live in the gesture tip and hint system. The card should be one phrase: what to do.

**Files:** `Localizable.xcstrings`

Visual objectives:
- [ ] `dungeon.l1.objective.format` → `"Align the Moonstone with the orb."`
- [ ] `dungeon.l2.objective.format` → `"Align the Moonstone — timer running."`
- [ ] `dungeon.l3.objective.format` → `"Align the Moonstone — timer running."`

VoiceOver objectives (currently repeat gesture instructions):
- [ ] `dungeon.a11y.l1.objective.format` → `"Align the Moonstone with the orb."`
- [ ] `dungeon.a11y.l2.objective.format` → `"Align the Moonstone before time runs out."`
- [ ] `dungeon.a11y.l3.objective.format` → `"Align the Moonstone quickly — time is short."`

**Verify:** On each level, VoiceOver reads the objective card and announces only the task — no gesture instructions embedded in the read.

---

## Task 3 — Fix scroll status (announced after every 3-finger swipe)

**Why:** Current format is "Moonstone. Crystal orb, faint resonance." The "Crystal orb," prefix repeats on every swipe announcement — it adds nothing after the first time. Replace with action-oriented band labels.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.resonance.a11y.orb.far` → `"Far — keep scrolling"`
- [ ] `dungeon.resonance.a11y.orb.warm` → `"Getting warmer"`
- [ ] `dungeon.resonance.a11y.orb.near` → `"Almost aligned"`
- [ ] `dungeon.resonance.a11y.orb.locked` → `"Aligned — seal it"`

**Verify:** VoiceOver on → scroll the glyph stream → hear "Moonstone. Aligned — seal it." not "Moonstone. Crystal orb, aligned, ready to seal resonance."

---

## Task 4 — Fix gesture tip card (in-game, L1)

**Why:** The third line is too long and must match Task 1 zone naming.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.explain.gesture.swipe3u` → `"Aligned? Seal button appears below."`
- [ ] Zone tip line: same string as Task 1 (`dungeon.resonance.tip.voFocusOnLane`).

**Verify:** Gesture tip card on L1 reads cleanly in three short lines.

**Optional cleanup:** Rename localization key `voFocusOnLane` → `voFocusOnGlyphStream` in code + catalog when you touch that string (reduces future confusion).

---

## Task 5 — Fix wrong-target feedback and not-reachable text

**Why:** Both strings are verbose and one gives a directional hint that can be wrong.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.feedback.non_target` → `"Not the Moonstone. Keep scrolling."`
- [ ] `dungeon.target.notReachable` → `"Moonstone not aligned yet."` *(drop "too deep" / "scroll down" — Moonstone can be above or below)*

**Verify:** Tap a decoy → hear "Not the Moonstone. Keep scrolling." — Seal button disabled → status shows "Moonstone not aligned yet."

---

## Task 6 — Trim seal button hint

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.resonance.seal.hint` → `"Seals when the Moonstone is aligned."`

---

## Task 7 — Fix Lights Off flavor text

**Why:** Current text is pure instruction with no atmosphere.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.lightsOff.flavor` → `"Darkness falls. Navigate by sound alone."`

**Verify:** L3 lights-off flavor card shows the new text.

---

## Task 8 — Timer 75% key (✅ logic verified — rename for clarity optional)

**Why:** The *string key* says `75pct` but the code fires at **75% of time elapsed** (= **25% time left**). That matches copy like **"Quarter time left."** There is no threshold bug in `startTimer` today.

**Verified behavior** (`iOSDungeonDescentView.swift`): `pctElapsed >= 0.75` → `announceTimerThreshold(..., 0.75)` → `dungeon.a11y.timer.75pct`.

**Suggested improvements (pick one):**
- [ ] **Documentation only:** Add a one-line comment above `announceTimerThreshold` or next to the `0.75` branch: *“Announced when ~25% of time remains.”*
- [ ] **Or** rename the localization key to something like `dungeon.a11y.timer.quarterRemaining` and update call sites (avoids the next reader misreading “75pct” as “75% left”).

**Also note:** Enchanter uses **`simon.a11y.timer.75pct`** with the *same* elapsed-fraction pattern — if you rename dungeon keys for clarity, consider matching Enchanter for consistency.

**Verify:** L3 (45s): at ~33.75s elapsed, hear the quarter-remaining line once; at 50% / 25% elapsed, hear the other thresholds.

---

## Task 9 — Tighten timeout and result strings

**Product note:** These lines add back **theme** (gate, shaft, crystal). That’s fine if the goal is *flavor on results* while keeping *instructional* copy terse elsewhere. If you want maximum plainness everywhere, keep shorter defeat/pass strings instead.

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.timeout` → `"Time's up. The gate sealed."`
- [ ] `dungeon.results.legendary` → `"Flawless. The crystal answers you."`
- [ ] `dungeon.results.skilled` → `"Well done. The shaft yields."`
- [ ] `dungeon.results.novice` → `"Sealed. The crystal tested you — and you endured."`
- [ ] `dungeon.results.defeated` → `"The gate sealed. Rest, then try again."`

---

## Task 10 — Prologue copy tightening

**Files:** `Localizable.xcstrings`

- [ ] `dungeon.explain.lesson.body` → `"Practice three-finger scrolling below."`
- [ ] `dungeon.explain.narration` → covered in Task 1

**Verify:** Prologue screen reads cleanly without redundant spell-card cross-references.

---

## Strings to Leave Unchanged

These are working well — concise, thematic, correct:
- Room names and subtitles (`Entry Hall`, `"Torchlit. Safe."`, etc.)
- Level titles (`"First Attempt"`, `"Rising Challenge"`, `"Timed Trial"`)
- Item names (`"Moonstone"`, `"Ember Shard"`, `"Shadow Glyph"`, `"Sun Sigil"`)
- Countdown sequence (`"One."` … `"Ten seconds."`)
- Button labels (`"Activate the Seal"`, `"Begin Trial"`, `"Continue"`, `"Try Again"`)
- DM label (`"Resonance Guide"`)

---

## Zone Naming Convention (for future quests)

Any quest that requires the user to focus a specific zone to perform a gesture should name that zone:

> `[Thematic noun describing the content] + [spatial or motion word]`

| Quest type | Example zone name |
|-----------|-----------------|
| Crystal Resonance | **Glyph stream** |
| Rhythm/sequence | **Rune beat** / **Spell cadence** |
| Selection grid | **Sigil field** / **Relic array** |
| Path navigation | **Cipher path** / **Rune channel** |

Quests where focus works on individual elements (Banishment, Enchanter's Trial) do not need a named zone.

---

## Scope — beyond `Localizable.xcstrings` (Glyph stream rename)

If **Glyph stream** becomes canonical, grep and update or annotate:

| Area | Examples |
|------|-----------|
| Swift comments / Quick Help | `iOSDungeonDescentView.swift`, `iOSDungeonResonancePlayView.swift`, `DungeonRoom` |
| RA11yCore | `GameDefinition.swift`, `QuestFeedbackProfile.swift`, `QuestFeedbackTypes.swift` |
| Requirements / research | `memlog/requirements/Design/CrystalResonance-Terminology.txt`, `DungeonResonanceAssetPipeline.txt`, `memlog/research/CrystalResonance-*.md` |
| Related product doc | `memlog/requirements/Design/VoiceOver-GestureSpell-Vocabulary.md` (spell card examples) |

UITests and screenshot docs that quote the old phrase should be updated when copy ships.
