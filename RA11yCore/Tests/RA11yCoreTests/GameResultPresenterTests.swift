import Testing
@testable import RA11yCore

// MARK: - GameResultPresenterTests

/// Tests for `GameResultPresenter` formatting and accessibility announcement.
///
/// Validates TICKET-M1-SharedGameResultScreen unit test requirement:
/// rank is announced first, followed by time, then mistakes.
struct GameResultPresenterTests {

    @Test func accessibilityAnnouncementStartsWithRank() {
        let result    = GameResult(gameID: "g", rank: .perfect, timeSeconds: 8.5, mistakes: 0)
        let presenter = GameResultPresenter(result: result)
        #expect(presenter.accessibilityAnnouncement.hasPrefix("Perfect"))
    }

    @Test func accessibilityAnnouncementContainsTimeAndMistakes() {
        let result    = GameResult(gameID: "g", rank: .perfect, timeSeconds: 8.5, mistakes: 0)
        let presenter = GameResultPresenter(result: result)
        let text      = presenter.accessibilityAnnouncement
        #expect(text.contains("8.5 seconds"))
        #expect(text.contains("0 mistakes"))
    }

    @Test func singularMistakeFormatting() {
        let result    = GameResult(gameID: "g", rank: .good, timeSeconds: 20, mistakes: 1)
        let presenter = GameResultPresenter(result: result)
        #expect(presenter.formattedMistakes == "1 mistake")
    }

    @Test func pluralMistakesFormatting() {
        let result    = GameResult(gameID: "g", rank: .ok, timeSeconds: 30, mistakes: 3)
        let presenter = GameResultPresenter(result: result)
        #expect(presenter.formattedMistakes == "3 mistakes")
    }

    @Test func formattedTimeIncludesOneDecimalPlace() {
        let result    = GameResult(gameID: "g", rank: .good, timeSeconds: 12.0, mistakes: 0)
        let presenter = GameResultPresenter(result: result)
        #expect(presenter.formattedTime == "12.0 seconds")
    }

    @Test func failedRankAnnouncedCorrectly() {
        let result    = GameResult(gameID: "g", rank: .failed, timeSeconds: 46, mistakes: 3)
        let presenter = GameResultPresenter(result: result)
        #expect(presenter.accessibilityAnnouncement.hasPrefix("Failed"))
    }
}
