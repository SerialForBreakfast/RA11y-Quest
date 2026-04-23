# Quest timer model audit (RA11y)

**Goal:** Enchanter’s pattern — **per phase or per beat** `start` / `stop` / `onTimeout` — is the product standard; games should not mix one-off ad hoc walls without a documented reason.

## Reference: Enchanter (`iOSEnchantersTrialView` + `EnchanterTrialViewModel`)

- L1: untimed; L2: **45s** for that phase; L3: **20s** for timed trial.
- `startTimer` / `stopTimer` in the view model; timeout handlers set phase or outcome.
- **GameSession** only for the final scored phase (L3) in the current build.

## The Banishment (`iOSBanishmentQuestView` + `BanishmentQuestViewModel`) — *updated*

- **Ward:** practice, **no** scored segment clock.
- **Scored `GameSession`:** one run from `beginScoredGauntlet` through `complete` or abandon.
- **UI countdown:** **per-encounter** — three tower segment budgets + one dark budget (sums to `RankThresholds.banishment.timeoutSeconds` = 55s).
- **Rank:** still from `GameSession` elapsed wall time and mistake count vs `RankThresholds.banishment`.

## Crystal Resonance / Dungeon (`iOSDungeonDescentView` + `iOSDungeonResonancePlayView`)

- L1/L2: soft timers; L3: **one** `GameSession` for scroll trial; structure is already phase-based.
- **Action:** when touching timers here, keep **Enchanter-style** naming and start/stop discipline; no change required in this pass unless a bug is found.

## Follow-up

- Optional: add **unit** or **UI** tests for Banishment segment rollover and timeout `GameResult` time.
- Revisit the **3s** VoiceOver delay before the first segment timer: product may want a **shorter** delay or a **“ready”** affordance (not implemented here).
