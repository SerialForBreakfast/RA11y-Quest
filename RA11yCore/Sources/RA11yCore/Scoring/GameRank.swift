// MARK: - GameRank

/// Rank awarded to a completed game session, ordered from worst to best.
///
/// Raw `Int` values power `Comparable` ordering — higher = better rank.
/// Display names follow the D&D theme established in `GameRules-MVP.txt`.
/// All cases are `Codable` for persistence in `GameResult`.
public enum GameRank: Int, Comparable, Hashable, Sendable, Codable, CaseIterable {

    /// Session timed out or exceeded mistake thresholds.
    case failed = 0

    /// Session completed within relaxed time and mistake thresholds.
    case ok = 1

    /// Session completed within moderate time and mistake thresholds.
    case good = 2

    /// Session completed within tight time limit with zero or minimal mistakes.
    case perfect = 3

    // MARK: Comparable

    public static func < (lhs: GameRank, rhs: GameRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: Display

    /// D&D-themed display text for badges, result screens, and VoiceOver announcements.
    ///
    /// Used by `GameResultPresenter.accessibilityAnnouncement` and `iOSRankBadgeView`.
    /// The hub shows "Quest Awaits" for a nil (unplayed) rank — that string lives in
    /// `Localizable.xcstrings` as `"hub.questAwaits"`, not here.
    public var displayText: String {
        switch self {
        case .failed:  return "Defeated"
        case .ok:      return "Novice"
        case .good:    return "Skilled"
        case .perfect: return "Legendary"
        }
    }

    /// SF Symbol name representing the rank without relying on color alone.
    ///
    /// Used on the result screen and as a semantic fallback.
    /// The hub quest board renders custom Canvas shapes instead — see `iOSRankBadgeView`.
    public var symbolName: String {
        switch self {
        case .failed:  return "shield.slash"
        case .ok:      return "circle"
        case .good:    return "shield"
        case .perfect: return "star.fill"
        }
    }
}
