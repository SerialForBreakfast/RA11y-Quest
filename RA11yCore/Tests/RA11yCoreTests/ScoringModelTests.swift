import Testing
@testable import RA11yCore

// MARK: - ScoringModelTests

/// Tests for `GameRank`, `GameResult.isBetter(than:)`, and `RankThresholds.evaluate`.
///
/// All threshold assertions use values from `GameSpec-FindAndFocus.txt`,
/// `GameSpec-ActivateDoubleTap.txt`, `GameSpec-ScrollHunt.txt`, and
/// `GameRules-MVP.txt`. Update tests here whenever a spec changes.
struct ScoringModelTests {

    // MARK: - GameRank Display Names

    /// Regression guard: D&D display names must not regress to code-level names.
    @Test func gameRankDisplayNamesMatchDandDTheme() {
        #expect(GameRank.perfect.displayText == "Legendary")
        #expect(GameRank.good.displayText    == "Skilled")
        #expect(GameRank.ok.displayText      == "Novice")
        #expect(GameRank.failed.displayText  == "Defeated")
    }

    // MARK: - GameRank Comparable Ordering

    @Test func gameRankComparableOrderingIsCorrect() {
        #expect(GameRank.failed  < GameRank.ok)
        #expect(GameRank.ok      < GameRank.good)
        #expect(GameRank.good    < GameRank.perfect)
        #expect(!(GameRank.perfect < GameRank.failed))
        #expect(!(GameRank.perfect < GameRank.perfect))
    }

    // MARK: - isBetter(than:)

    /// Higher rank wins regardless of time or mistakes.
    @Test func higherRankAlwaysWins() {
        let perfect = GameResult(gameID: "g", rank: .perfect, timeSeconds: 30, mistakes: 5)
        let good    = GameResult(gameID: "g", rank: .good,    timeSeconds: 5,  mistakes: 0)
        #expect(perfect.isBetter(than: good))
        #expect(!good.isBetter(than: perfect))
    }

    /// On equal rank, fewer mistakes wins.
    @Test func fewerMistakesWinsOnEqualRank() {
        let fewer = GameResult(gameID: "g", rank: .good, timeSeconds: 15, mistakes: 0)
        let more  = GameResult(gameID: "g", rank: .good, timeSeconds: 10, mistakes: 1)
        #expect(fewer.isBetter(than: more))
    }

    /// On equal rank and equal mistakes, faster time wins.
    @Test func fasterTimeWinsOnEqualRankAndMistakes() {
        let faster = GameResult(gameID: "g", rank: .good, timeSeconds: 12, mistakes: 1)
        let slower = GameResult(gameID: "g", rank: .good, timeSeconds: 18, mistakes: 1)
        #expect(faster.isBetter(than: slower))
    }

    /// A result is never better than an identical result — prevents infinite promotion loops.
    @Test func resultIsNotBetterThanItself() {
        let result = GameResult(gameID: "g", rank: .perfect, timeSeconds: 8, mistakes: 0)
        #expect(!result.isBetter(than: result))
    }

    // MARK: - RankThresholds — Find & Focus (Game 1 — The Enchanter's Trial)
    // Spec: Legendary ≤10s, 0 mistakes | Skilled ≤20s, ≤1 mistake | Novice ≤45s | Defeated ≥5 mistakes

    /// Legendary: 0 mistakes AND ≤10s — exact ticket spec value.
    @Test func findAndFocusLegendaryWithinThreshold() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 9, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// Exactly 10s with 0 mistakes is Legendary (boundary included).
    @Test func findAndFocusLegendaryAtExactBoundary() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 10, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// 11s with 0 mistakes drops to Skilled (just past perfect boundary).
    @Test func findAndFocusJustPastPerfectTimeDropsToSkilled() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 11, mistakes: 0)
        #expect(rank == .good)
    }

    /// 1 mistake at ≤10s drops to Skilled (mistake exceeds perfect threshold).
    @Test func findAndFocusOneMistakeDropsFromLegendary() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 9, mistakes: 1)
        #expect(rank == .good)
    }

    /// Skilled: ≤20s, ≤1 mistake — exact spec values.
    @Test func findAndFocusSkilledWithinThreshold() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 20, mistakes: 1)
        #expect(rank == .good)
    }

    /// 21s with 1 mistake drops to Novice.
    @Test func findAndFocusJustPastSkilledTimeDropsToNovice() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 21, mistakes: 1)
        #expect(rank == .ok)
    }

    /// Novice: success within 45s with 2 mistakes (well below defeat threshold of 5).
    @Test func findAndFocusNoviceWithinBoundary() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 40, mistakes: 3)
        #expect(rank == .ok)
    }

    /// Exactly at the 45s timeout is still Novice (guard is strict >).
    @Test func findAndFocusExactTimeoutIsNovice() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 45, mistakes: 0)
        #expect(rank == .ok)
    }

    /// Fractionally past 45s is Defeated — session would have been abandoned by timer.
    @Test func findAndFocusJustOverTimeoutIsDefeated() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 45.001, mistakes: 0)
        #expect(rank == .failed)
    }

    /// 5 mistakes triggers Defeated regardless of time (okMaxMistakes = 4).
    @Test func findAndFocusFiveMistakesDefeated() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 5, mistakes: 5)
        #expect(rank == .failed)
    }

    /// 4 mistakes with fast time is still Novice (boundary: okMaxMistakes = 4).
    @Test func findAndFocusFourMistakesIsNovice() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 5, mistakes: 4)
        #expect(rank == .ok)
    }

    // MARK: - RankThresholds — Crystal Resonance (Game 2)
    // Spec: Legendary ≤15s, 0 mistakes | Skilled ≤30s, ≤1 mistake | Novice ≤60s | Defeated ≥6 mistakes

    /// Legendary: ≤15s, 0 mistakes (spec exact value from GameSpec-ScrollHunt.txt).
    @Test func scrollHuntLegendaryAtExactThreshold() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 15, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// Skilled: ≤30s, ≤1 mistake.
    @Test func scrollHuntSkilledWithinThreshold() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 28, mistakes: 1)
        #expect(rank == .good)
    }

    /// Novice: completed, ≤60s, <6 mistakes.
    @Test func scrollHuntNoviceWithinBoundary() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 55, mistakes: 4)
        #expect(rank == .ok)
    }

    /// 6 mistakes → Defeated (okMaxMistakes = 5, so 6 exceeds it).
    @Test func scrollHuntSixMistakesDefeated() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 20, mistakes: 6)
        #expect(rank == .failed)
    }

    /// >60s → Defeated.
    @Test func scrollHuntFailedOnTimeout() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 60.001, mistakes: 0)
        #expect(rank == .failed)
    }

    // MARK: - RankThresholds — The Banishment

    @Test func banishmentLegendaryWithinThreshold() {
        let rank = RankThresholds.banishment.evaluate(timeSeconds: 12, mistakes: 0)
        #expect(rank == .perfect)
    }

    @Test func banishmentFailedOnTimeout() {
        let rank = RankThresholds.banishment.evaluate(timeSeconds: 55.001, mistakes: 0)
        #expect(rank == .failed)
    }

    // MARK: - RankThresholds — The Threefold Seal (`arcanists-tower`)

    @Test func arcanistsTowerLegendaryWithinThreshold() {
        let rank = RankThresholds.arcanistsTower.evaluate(timeSeconds: 25, mistakes: 0)
        #expect(rank == .perfect)
    }

    @Test func arcanistsTowerFailedOnTimeout() {
        let rank = RankThresholds.arcanistsTower.evaluate(timeSeconds: 60.001, mistakes: 0)
        #expect(rank == .failed)
    }

    // MARK: - RankThresholds.bucketMistakes
    //
    // Spec (GameSpec-FindAndFocus.txt):
    //   "Bucket size: 10s. First bucket (0–10s) is free. Each subsequent full 10s adds +1.
    //   Example: 0–10s → +0; 10–20s → +1; 20–30s → +2."

    /// 0s (no time elapsed) → 0 bucket mistakes.
    @Test func bucketMistakesZeroTime() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 0) == 0)
    }

    /// < 10s: first bucket still running → 0 penalties.
    @Test func bucketMistakesWithinFirstBucket() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 5) == 0)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 9.9) == 0)
    }

    /// Exactly 10s: edge of first bucket → 0 penalties (first bucket is free).
    @Test func bucketMistakesExactlyAtFirstBucketBoundary() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 10) == 0)
    }

    /// 10–20s range: first paid bucket → +1.
    @Test func bucketMistakesSecondBucket() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 10.001) == 1)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 15) == 1)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 20) == 1)
    }

    /// 20–30s range → +2.
    @Test func bucketMistakesThirdBucket() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 20.001) == 2)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 25) == 2)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 30) == 2)
    }

    /// Custom bucket size: 5s.
    @Test func bucketMistakesCustomBucketSize() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 5,    bucketSize: 5) == 0)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 5.01, bucketSize: 5) == 1)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 10,   bucketSize: 5) == 1)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 10.01, bucketSize: 5) == 2)
    }

    /// Negative or zero bucket size → 0 (guard against bad input).
    @Test func bucketMistakesInvalidBucketSize() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 30, bucketSize: 0)  == 0)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 30, bucketSize: -1) == 0)
    }

    // MARK: - RankThresholds.bucketMistakes (8s bucket regression)
    //
    // Exercises a non-default bucket size; retained after retiring the old activate quest.

    /// Within first 8s bucket → 0 penalties.
    @Test func bucketMistakesEightSecond_withinFirstBucket() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 0,   bucketSize: 8) == 0)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 4,   bucketSize: 8) == 0)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 8,   bucketSize: 8) == 0)
    }

    /// Just past 8s → enters second bucket → +1.
    @Test func bucketMistakesEightSecond_secondBucket() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 8.001, bucketSize: 8) == 1)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 12,    bucketSize: 8) == 1)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 16,    bucketSize: 8) == 1)
    }

    /// Just past 16s → enters third bucket → +2.
    @Test func bucketMistakesEightSecond_thirdBucket() {
        #expect(RankThresholds.bucketMistakes(timeSeconds: 16.001, bucketSize: 8) == 2)
        #expect(RankThresholds.bucketMistakes(timeSeconds: 20,     bucketSize: 8) == 2)
    }
}
