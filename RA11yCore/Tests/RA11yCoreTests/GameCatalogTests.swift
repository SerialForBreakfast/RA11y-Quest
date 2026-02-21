import Testing
@testable import RA11yCore

// MARK: - GameCatalogTests

/// Tests for `GameCatalog` lookup and `GameDefinition` shape.
///
/// Validates TICKET-M1-GameCatalog-Definitions acceptance criteria:
/// catalog IDs are stable and lookup returns the correct definition.
struct GameCatalogTests {

    @Test func lookupByKnownIDReturnsCorrectDefinition() {
        let def = GameCatalog.definition(for: "find-and-focus")
        #expect(def != nil)
        #expect(def?.kind == .findAndFocus)
        #expect(def?.titleKey == "game.findAndFocus.title")
        #expect(def?.goalKey == "game.findAndFocus.goal")
    }

    @Test func lookupByUnknownIDReturnsNil() {
        #expect(GameCatalog.definition(for: "not-a-real-game") == nil)
    }

    @Test func allGamesHaveUniqueIDs() {
        let ids = GameCatalog.all.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "Duplicate game IDs detected")
    }

    @Test func allThreeMVPGamesPresent() {
        let kinds = Set(GameCatalog.all.map(\.kind))
        #expect(kinds.contains(.findAndFocus))
        #expect(kinds.contains(.activateDoubleTap))
        #expect(kinds.contains(.scrollHunt))
    }
}
