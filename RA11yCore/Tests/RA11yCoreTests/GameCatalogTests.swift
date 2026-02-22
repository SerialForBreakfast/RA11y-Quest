import Testing
@testable import RA11yCore

// MARK: - GameCatalogTests

/// Tests for `GameCatalog` lookup, catalog shape, and per-game contract requirements.
///
/// Validates TICKET-M1-GameCatalog-Definitions acceptance criteria:
/// stable IDs, no duplicates, correct kind associations, and non-empty asset data.
struct GameCatalogTests {

    // MARK: - Lookup

    @Test func lookupByKnownIDReturnsCorrectDefinition() {
        let def = GameCatalog.definition(for: "find-and-focus")
        #expect(def != nil)
        #expect(def?.kind == .findAndFocus)
        #expect(def?.titleKey == "game.findAndFocus.title")
        #expect(def?.goalKey  == "game.findAndFocus.goal")
    }

    @Test func lookupByUnknownIDReturnsNil() {
        #expect(GameCatalog.definition(for: "not-a-real-game") == nil)
    }

    // MARK: - Catalog Integrity

    /// Duplicate IDs would silently break storage lookup — they must not exist.
    @Test func allGamesHaveUniqueIDs() {
        let ids    = GameCatalog.all.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "Duplicate game IDs detected: \(ids)")
    }

    /// Each `GameKind` must map to exactly one game.
    ///
    /// More than one game per kind would cause routing ambiguity.
    @Test func eachGameKindHasExactlyOneGame() {
        for kind in GameKind.allCases {
            let matches = GameCatalog.all.filter { $0.kind == kind }
            #expect(matches.count == 1, "\(kind) appears \(matches.count) times in catalog")
        }
    }

    /// All three MVP games must be present in the catalog.
    @Test func allThreeMVPGamesPresent() {
        let kinds = Set(GameCatalog.all.map(\.kind))
        #expect(kinds.contains(.findAndFocus))
        #expect(kinds.contains(.activateDoubleTap))
        #expect(kinds.contains(.scrollHunt))
    }

    // MARK: - Per-Game Data Contract

    /// Empty thumbnail asset names break hub card rendering. Non-empty is required.
    @Test func allGamesHaveNonEmptyThumbnailAssetName() {
        for game in GameCatalog.all {
            #expect(!game.thumbnailAssetName.isEmpty, "\(game.id) has empty thumbnailAssetName")
        }
    }

    /// Empty duration strings render blank in the hub card and in accessibility labels.
    @Test func allGamesHaveNonEmptyEstimatedDuration() {
        for game in GameCatalog.all {
            #expect(!game.estimatedDuration.isEmpty, "\(game.id) has empty estimatedDuration")
        }
    }

    /// Title and goal localization keys must be non-empty; absent keys produce empty UI strings.
    @Test func allGamesHaveNonEmptyLocalizationKeys() {
        for game in GameCatalog.all {
            #expect(!game.titleKey.isEmpty, "\(game.id) has empty titleKey")
            #expect(!game.goalKey.isEmpty,  "\(game.id) has empty goalKey")
        }
    }
}
