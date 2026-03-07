import Foundation

// MARK: - GameKind

/// Identifies the routing and logic variant for a training game.
///
/// - Important: Raw values are stable routing identifiers. Do not rename or reorder post-ship.
public enum GameKind: String, Hashable, Sendable, Codable, CaseIterable {
    /// Find & Focus — Simon Says drill training focus navigation and element identification.
    case findAndFocus
    /// Activate — Bomb Defusal drill training double-tap activation on the correct control.
    case activateDoubleTap
    /// Scroll Hunt — Dungeon Crawl drill training scrolling to reveal hidden content.
    case scrollHunt
}

// MARK: - GameDefinition

/// Immutable descriptor for a single training game in the catalog.
///
/// Text fields are localization keys resolved at the UI layer via `String(localized:)`.
/// Asset names are placeholder references until design assets land before M5.
///
/// - Note: `id` is the stable storage key. It must never change after the app ships.
public struct GameDefinition: Sendable, Identifiable {

    /// Stable identifier used as the storage key. Never change after first ship.
    public let id: String

    /// Localization key for the display title (e.g., `"game.findAndFocus.title"`).
    public let titleKey: String

    /// Localization key for the one-line goal description.
    public let goalKey: String

    /// Human-readable estimated duration shown in the hub card (e.g., `"~30s"`).
    public let estimatedDuration: String

    /// Routing and game-logic variant.
    public let kind: GameKind

    /// Primary thumbnail asset name. Placeholder accepted at M1; replaced by M5.
    public let thumbnailAssetName: String

    /// - Parameters:
    ///   - id: Stable storage key — must never change post-ship.
    ///   - titleKey: Localization key for display title.
    ///   - goalKey: Localization key for one-line goal.
    ///   - estimatedDuration: Human-readable duration string.
    ///   - kind: Game logic and routing kind.
    ///   - thumbnailAssetName: Asset catalog name for the hub thumbnail.
    public init(
        id: String,
        titleKey: String,
        goalKey: String,
        estimatedDuration: String,
        kind: GameKind,
        thumbnailAssetName: String
    ) {
        self.id = id
        self.titleKey = titleKey
        self.goalKey = goalKey
        self.estimatedDuration = estimatedDuration
        self.kind = kind
        self.thumbnailAssetName = thumbnailAssetName
    }
}

// MARK: - GameCatalog

/// Static catalog of all MVP training games.
///
/// The catalog is the single source of truth for game metadata. Hub UI reads from here;
/// no game data is hardcoded in views.
///
/// - Note: Game IDs used here must match the storage keys used in `StorageComponent`.
public enum GameCatalog {

    /// All MVP games in display order.
    ///
    /// Thumbnails use dedicated square hub icons (`*_hub_icon`) designed for
    /// the dark quest card at ~72–96 pt. Background scene images and individual
    /// sprite assets are not used here as they either crop poorly or have
    /// white backgrounds that clash with the dark card surface.
    public static let all: [GameDefinition] = [
        GameDefinition(
            id: "find-and-focus",
            titleKey: "game.findAndFocus.title",
            goalKey: "game.findAndFocus.goal",
            estimatedDuration: "~5 min",
            kind: .findAndFocus,
            thumbnailAssetName: "enchanter_hub_icon"
        ),
        GameDefinition(
            id: "activate-double-tap",
            titleKey: "game.activateDoubleTap.title",
            goalKey: "game.activateDoubleTap.goal",
            estimatedDuration: "~5 min",
            kind: .activateDoubleTap,
            thumbnailAssetName: "rogue_hub_icon"
        ),
        GameDefinition(
            id: "scroll-hunt",
            titleKey: "game.scrollHunt.title",
            goalKey: "game.scrollHunt.goal",
            estimatedDuration: "~7 min",
            kind: .scrollHunt,
            thumbnailAssetName: "dungeon_hub_icon"
        ),
    ]

    /// Returns the `GameDefinition` matching the given stable ID, or `nil` if not found.
    ///
    /// - Parameter id: The stable catalog ID (e.g., `"find-and-focus"`).
    public static func definition(for id: String) -> GameDefinition? {
        all.first { $0.id == id }
    }
}
