import Testing
@testable import RA11yCore

// MARK: - ScoringModelTests

/// Tests for `GameRank` ordering and display, `GameResult.isBetter(than:)`, and
/// `RankThresholds.evaluate(timeSeconds:mistakes:)`.
///
/// Validates TICKET-M1-ScoringModel-RankMetrics acceptance criteria.
struct ScoringModelTests {

    // MARK: - GameRank Display Names

    /// All four rank cases must use D&D-themed display text.
    /// Regression guard: changing "Legendary" back to "Perfect" breaks this test.
    @Test func gameRankDisplayNamesMatchDandDTheme() {
        #expect(GameRank.perfect.displayText == "Legendary")
        #expect(GameRank.good.displayText    == "Skilled")
        #expect(GameRank.ok.displayText      == "Novice")
        #expect(GameRank.failed.displayText  == "Defeated")
    }

    // MARK: - GameRank Comparable Ordering

    /// `isBetter(than:)` and storage promotion depend on `Comparable` being correct.
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
        let fewer = GameResult(gameID: "g", rank: .good, timeSeconds: 25, mistakes: 1)
        let more  = GameResult(gameID: "g", rank: .good, timeSeconds: 20, mistakes: 2)
        #expect(fewer.isBetter(than: more))
    }

    /// On equal rank and equal mistakes, faster time wins.
    @Test func fasterTimeWinsOnEqualRankAndMistakes() {
        let faster = GameResult(gameID: "g", rank: .good, timeSeconds: 15, mistakes: 1)
        let slower = GameResult(gameID: "g", rank: .good, timeSeconds: 20, mistakes: 1)
        #expect(faster.isBetter(than: slower))
    }

    /// A result is never better than an identical result — prevents infinite promotion loops.
    @Test func resultIsNotBetterThanItself() {
        let result = GameResult(gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0)
        #expect(!result.isBetter(than: result))
    }

    // MARK: - RankThresholds — Find & Focus (Game 1)

    /// Perfect: ≤15s, 0 mistakes.
    @Test func findAndFocusPerfectWithinThreshold() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 15, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// Exactly at the perfect time boundary is still Perfect.
    @Test func findAndFocusPerfectAtExactTimeBoundary() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 15.0, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// One mistake at perfect time → degrades to Good.
    @Test func findAndFocusPerfectDegradesToGoodWithMistake() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 9, mistakes: 1)
        #expect(rank == .good)
    }

    /// Good: ≤25s, ≤1 mistake.
    @Test func findAndFocusGoodWithinThreshold() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 25, mistakes: 1)
        #expect(rank == .good)
    }

    /// Ok: ≤45s (timeout), ≤2 mistakes — the untested ok tier.
    @Test func findAndFocusOkRankWithinBoundary() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 40, mistakes: 2)
        #expect(rank == .ok)
    }

    /// Exactly at the timeout ceiling is still evaluated (not auto-failed).
    /// The guard is `timeSeconds > timeoutSeconds` (strict), so timeout itself passes.
    @Test func findAndFocusExactTimeoutIsNotFailed() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 45, mistakes: 0)
        #expect(rank == .ok)
    }

    /// One fraction over the timeout → failed, regardless of mistakes.
    @Test func findAndFocusJustOverTimeoutIsFailed() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 45.001, mistakes: 0)
        #expect(rank == .failed)
    }

    /// Absolute timeout regardless of time: mistakes > okMaxMistakes → failed even with fast time.
    @Test func findAndFocusExcessMistakesFailEvenWithFastTime() {
        // 3 mistakes exceeds all tiers (okMaxMistakes=2); time is well within range
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 5, mistakes: 3)
        #expect(rank == .failed)
    }

    // MARK: - RankThresholds — Activate Double-Tap (Game 2)

    /// Perfect: ≤20s, 0 mistakes.
    @Test func activateDoubleTapPerfectWithinThreshold() {
        let rank = RankThresholds.activateDoubleTap.evaluate(timeSeconds: 20, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// Good: ≤35s, ≤1 mistake.
    @Test func activateDoubleTapGoodWithinThreshold() {
        let rank = RankThresholds.activateDoubleTap.evaluate(timeSeconds: 35, mistakes: 1)
        #expect(rank == .good)
    }

    /// Ok: ≤60s (timeout ceiling), ≤2 mistakes.
    @Test func activateDoubleTapOkWithinBoundary() {
        let rank = RankThresholds.activateDoubleTap.evaluate(timeSeconds: 55, mistakes: 2)
        #expect(rank == .ok)
    }

    /// Over 60s → failed.
    @Test func activateDoubleTapFailedOnTimeout() {
        let rank = RankThresholds.activateDoubleTap.evaluate(timeSeconds: 60.001, mistakes: 0)
        #expect(rank == .failed)
    }

    // MARK: - RankThresholds — Scroll Hunt (Game 3)

    /// Perfect: ≤15s, 0 mistakes (exact boundary).
    @Test func scrollHuntPerfectAtExactThreshold() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 15, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// Over 60s → failed.
    @Test func scrollHuntFailedOnTimeout() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 60.001, mistakes: 0)
        #expect(rank == .failed)
    }
}
