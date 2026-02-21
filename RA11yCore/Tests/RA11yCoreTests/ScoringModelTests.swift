import Testing
@testable import RA11yCore

// MARK: - ScoringModelTests

/// Tests for `GameResult.isBetter(than:)` and `RankThresholds.evaluate(timeSeconds:mistakes:)`.
///
/// Validates TICKET-M1-ScoringModel-RankMetrics acceptance criteria.
struct ScoringModelTests {

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

    /// A result is not better than itself.
    @Test func resultIsNotBetterThanItself() {
        let result = GameResult(gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0)
        #expect(!result.isBetter(than: result))
    }

    // MARK: - RankThresholds — Find & Focus

    /// timeSeconds: 9, mistakes: 0 → Perfect (TICKET-M5 acceptance criteria).
    @Test func findAndFocusPerfectWithinThreshold() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 9, mistakes: 0)
        #expect(rank == .perfect)
    }

    /// timeSeconds: 46, mistakes: 0 → Failed (timeout exceeded).
    @Test func findAndFocusFailedOnTimeout() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 46, mistakes: 0)
        #expect(rank == .failed)
    }

    @Test func findAndFocusGoodWithinThreshold() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 20, mistakes: 1)
        #expect(rank == .good)
    }

    @Test func findAndFocusPerfectDegradesToGoodWithMistake() {
        let rank = RankThresholds.findAndFocus.evaluate(timeSeconds: 9, mistakes: 1)
        #expect(rank == .good)
    }

    // MARK: - RankThresholds — Scroll Hunt

    /// Perfect: 0 mistakes AND time ≤ 15s (TICKET-M7 acceptance criteria).
    @Test func scrollHuntPerfectAtExactThreshold() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 15, mistakes: 0)
        #expect(rank == .perfect)
    }

    @Test func scrollHuntFailedOnTimeout() {
        let rank = RankThresholds.scrollHunt.evaluate(timeSeconds: 61, mistakes: 0)
        #expect(rank == .failed)
    }
}
