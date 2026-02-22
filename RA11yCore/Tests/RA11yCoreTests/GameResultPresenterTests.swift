import Testing
@testable import RA11yCore

// MARK: - GameResultPresenterTests

/// Tests for `GameResultPresenter` formatting and VoiceOver accessibility announcements.
///
/// Validates TICKET-M1-SharedGameResultScreen:
/// - D&D rank names appear correctly in announcements.
/// - Announcement order is rank → time → mistakes.
/// - Singular/plural mistake grammar is correct.
struct GameResultPresenterTests {

    // MARK: - Accessibility Announcement: Ordering

    /// VoiceOver must read rank first so the player immediately knows their result.
    @Test func announcementStartsWithRankName() {
        let presenter = GameResultPresenter(result: GameResult(
            gameID: "g", rank: .perfect, timeSeconds: 8.5, mistakes: 0
        ))
        #expect(presenter.accessibilityAnnouncement.hasPrefix("Legendary"))
    }

    /// Rank → time → mistakes ordering is enforced.
    ///
    /// Verifies the TICKET-M1 requirement that information is announced in a
    /// specific order, not merely that all three values appear in the string.
    @Test func announcementOrderIsRankThenTimeThenMistakes() throws {
        let presenter = GameResultPresenter(result: GameResult(
            gameID: "g", rank: .good, timeSeconds: 15.0, mistakes: 2
        ))
        let text = presenter.accessibilityAnnouncement

        let rankEnd    = try #require(text.range(of: "Skilled")).upperBound
        let timeStart  = try #require(text.range(of: "15.0 seconds")).lowerBound
        let timeEnd    = try #require(text.range(of: "15.0 seconds")).upperBound
        let mistakeStart = try #require(text.range(of: "2 mistakes")).lowerBound

        #expect(rankEnd    <= timeStart,  "Rank must precede time in announcement")
        #expect(timeEnd    <= mistakeStart, "Time must precede mistakes in announcement")
    }

    /// All four D&D rank names must be used in the accessibility announcement.
    ///
    /// Regression guard: prevents reversion to the old "Perfect/Good/OK/Failed" names.
    @Test func allRanksAreAnnouncedWithDandDName() {
        let cases: [(GameRank, String)] = [
            (.perfect, "Legendary"),
            (.good,    "Skilled"),
            (.ok,      "Novice"),
            (.failed,  "Defeated"),
        ]
        for (rank, expectedPrefix) in cases {
            let presenter = GameResultPresenter(result: GameResult(
                gameID: "g", rank: rank, timeSeconds: 10, mistakes: 0
            ))
            #expect(
                presenter.accessibilityAnnouncement.hasPrefix(expectedPrefix),
                "Rank \(rank) should announce as '\(expectedPrefix)'"
            )
        }
    }

    // MARK: - Formatted Time

    @Test func formattedTimeIncludesOneDecimalPlace() {
        let presenter = GameResultPresenter(result: GameResult(
            gameID: "g", rank: .good, timeSeconds: 12.0, mistakes: 0
        ))
        #expect(presenter.formattedTime == "12.0 seconds")
    }

    // MARK: - Formatted Mistakes

    /// "1 mistake" — singular grammar.
    @Test func singularMistakeFormatting() {
        let presenter = GameResultPresenter(result: GameResult(
            gameID: "g", rank: .good, timeSeconds: 20, mistakes: 1
        ))
        #expect(presenter.formattedMistakes == "1 mistake")
    }

    /// "0 mistakes", "2 mistakes" — plural grammar.
    @Test func pluralMistakesFormatting() {
        let zero = GameResultPresenter(result: GameResult(
            gameID: "g", rank: .perfect, timeSeconds: 10, mistakes: 0
        ))
        let two = GameResultPresenter(result: GameResult(
            gameID: "g", rank: .ok, timeSeconds: 30, mistakes: 2
        ))
        #expect(zero.formattedMistakes != "1 mistake")  // 0 must not be singular
        #expect(zero.formattedMistakes == "0 mistakes")
        #expect(two.formattedMistakes  != "3 mistakes") // guard against off-by-one
        #expect(two.formattedMistakes  == "2 mistakes")
    }
}
