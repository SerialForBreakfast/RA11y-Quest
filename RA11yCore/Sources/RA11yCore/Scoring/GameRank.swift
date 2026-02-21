// MARK: - GameRank

/// Rank awarded to a completed game session, ordered from worst to best.
///
/// `Int` raw values enable `Comparable` ordering: higher raw value = better rank.
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

    /// Short, localized display text suitable for badges and VoiceOver announcement.
    public var displayText: String {
        switch self {
        case .failed:  return "Failed"
        case .ok:      return "OK"
        case .good:    return "Good"
        case .perfect: return "Perfect"
        }
    }

    /// SF Symbol name representing the rank without relying on color alone.
    public var symbolName: String {
        switch self {
        case .failed:  return "xmark.circle"
        case .ok:      return "minus.circle"
        case .good:    return "checkmark.circle"
        case .perfect: return "star.circle.fill"
        }
    }
}
