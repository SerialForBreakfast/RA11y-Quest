import Foundation

/// Declares every app scene that screenshot automation is allowed to boot directly.
///
/// The fastlane screenshot lane and the UI test suite treat this enum as the app-side
/// contract for deterministic capture. Each case maps to one committed PNG.
enum iOSScreenshotScene: String, CaseIterable {

    /// Game hub root screen.
    case hub = "hub"

    /// VoiceOver-required interstitial for a game launch.
    case voRequired = "voRequired"

    /// First-run entry screen.
    case firstRun = "firstRun"

    /// Enchanter L0 prologue.
    case enchanterPrologue = "enchanterPrologue"

    /// Enchanter L1 first attempt.
    case enchanterAttempt = "enchanterAttempt"

    /// Enchanter L2 rising challenge.
    case enchanterRising = "enchanterRising"

    /// Enchanter L3 timed trial.
    case enchanterTimed = "enchanterTimed"

    /// Shared result screen using Enchanter sample data.
    case enchanterResult = "enchanterResult"

    /// Dungeon L0 prologue.
    case dungeonPrologue = "dungeonPrologue"

    /// Dungeon L1 first attempt.
    case dungeonFirstAttempt = "dungeonFirstAttempt"

    /// Shared result screen using Dungeon sample data.
    case dungeonResult = "dungeonResult"

    /// Process argument name used to request a specific screenshot scene.
    static let launchArgument = "-screenshotScene"

    /// Resolves the requested screenshot scene from process arguments.
    ///
    /// - Parameter arguments: Launch arguments to inspect. Defaults to the current process.
    /// - Returns: The requested screenshot scene, or `nil` when no valid scene was requested.
    static func current(from arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
        guard let index = arguments.firstIndex(of: launchArgument) else { return nil }
        let sceneIndex = arguments.index(after: index)
        guard arguments.indices.contains(sceneIndex) else { return nil }
        return Self(rawValue: arguments[sceneIndex])
    }

    /// The committed PNG basename associated with this scene.
    var captureName: String {
        switch self {
        case .hub: return "01_Hub"
        case .voRequired: return "02_VORequired"
        case .firstRun: return "03_FirstRun"
        case .enchanterPrologue: return "04_EnchanterPrologue"
        case .enchanterAttempt: return "05_EnchanterAttempt"
        case .enchanterRising: return "06_EnchanterRising"
        case .enchanterTimed: return "07_EnchanterTimed"
        case .enchanterResult: return "08_EnchanterResult"
        case .dungeonPrologue: return "09_DungeonPrologue"
        case .dungeonFirstAttempt: return "10_DungeonL1"
        case .dungeonResult: return "11_DungeonResult"
        }
    }

    /// The root accessibility identifier that must exist before capture.
    var rootAccessibilityIdentifier: String {
        switch self {
        case .hub:
            return "hub.dmGreeting"
        case .voRequired:
            return "voRequired.title"
        case .firstRun:
            return "firstRun.title"
        case .enchanterPrologue:
            return "enchanter.prologue"
        case .enchanterAttempt:
            return "enchanter.attempt"
        case .enchanterRising:
            return "enchanter.rising"
        case .enchanterTimed:
            return "enchanter.timed"
        case .enchanterResult, .dungeonResult:
            return "gameResult.root"
        case .dungeonPrologue:
            return "dungeon.prologue"
        case .dungeonFirstAttempt:
            return "dungeon.firstAttempt"
        }
    }
}
