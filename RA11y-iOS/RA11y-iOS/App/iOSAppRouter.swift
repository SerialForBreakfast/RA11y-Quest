import OSLog
import SwiftUI
import RA11yCore

// MARK: - Route

/// All navigable destinations in the RA11y iOS app.
///
/// Add new cases here as features are introduced in later milestones.
/// All cases must remain `Hashable` for use with `NavigationStack`.
enum AppRoute: Hashable {
    /// The main game hub — lists all available training games.
    case hub
    /// The first-run "VoiceOver Basics" guided sequence. Implemented in M4.
    case firstRun(mode: FirstRunMode)
    /// Game 1 — The Enchanter's Trial (Find & Focus). Implemented in M5.
    case enchantersTrial
    /// Game 2 — The Rogue's Gauntlet (Activate / Double-Tap). Implemented in M6.
    case roguesGauntlet
    /// Game 3 — The Dungeon Descent (Scroll Hunt). Implemented in M7.
    case dungeonDescent
    /// The shared result screen shown after any game completes.
    /// Carries the `GameResult`, the `GameKind` (used to render the skill-transfer card),
    /// and an optional game-specific flavor announcement appended to the shared summary.
    case gameResult(GameResult, gameKind: GameKind, gameSpecificAnnouncement: String?)

    /// "VoiceOver required" interstitial shown when a user attempts to start a game
    /// with VoiceOver disabled. Carries the intended `GameKind` so the interstitial
    /// can offer the correct follow-up once the user enables VoiceOver.
    case voiceOverInterstitial(kind: GameKind)
}

// MARK: - FirstRunMode

/// Entry point for the "VoiceOver Basics" flow.
///
/// Controls whether the first-run screen is shown or the Basics sequence starts immediately.
enum FirstRunMode: Hashable {
    /// Show the first-run entry screen ("Start Basics" vs "Go to Hub").
    case entry
    /// Start the Basics sequence immediately (used by the hub entry point).
    case sequence
}

// MARK: - Router

/// Single source of truth for navigation state in the RA11y iOS app.
///
/// Owns the `NavigationPath` that drives the app's `NavigationStack`.
/// All routing decisions are made here, keeping views free of navigation logic.
///
/// Inject via SwiftUI environment (`.environment(router)`) from `iOSRootView`.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
/// All mutations are safe to call from SwiftUI views and `@Observable` observers.
@Observable
final class iOSAppRouter {

    // MARK: - State

    /// Navigation path driving the app's `NavigationStack`.
    /// An empty path displays the root destination (Hub).
    var path = NavigationPath()

    // MARK: - Computed

    /// The destination shown at app launch.
    ///
    /// Returns `.hub` at M0.
    /// M4 resolves the first-run entry path via `resolveInitialRoute(using:)`.
    var initialRoute: AppRoute { .hub }

    // MARK: - Navigation

    /// Pushes a destination onto the navigation stack.
    ///
    /// - Parameter route: The destination to navigate to.
    func push(_ route: AppRoute) {
        RA11yLogger.navigation.debug("Push → \(String(describing: route))")
        path.append(route)
    }

    /// Pops the topmost destination from the navigation stack.
    /// No-op if the stack is already at its root.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
        RA11yLogger.navigation.debug("Pop. Stack depth: \(self.path.count)")
    }

    /// Pops all destinations, returning to the root (Hub).
    func popToRoot() {
        path = NavigationPath()
        RA11yLogger.navigation.debug("Navigation reset to root")
    }

    // MARK: - First-Run Routing

    /// Resolves the initial route based on stored Basics flags.
    ///
    /// - Parameter storage: Persistence layer for first-run flags.
    /// - Returns: `.firstRun(mode: .entry)` when neither flag is set; otherwise `.hub`.
    func resolveInitialRoute(using storage: any StorageComponent) async -> AppRoute {
        if await storage.isBasicsCompleted() { return .hub }
        if await storage.isBasicsDismissed() { return .hub }
        return .firstRun(mode: .entry)
    }
}
