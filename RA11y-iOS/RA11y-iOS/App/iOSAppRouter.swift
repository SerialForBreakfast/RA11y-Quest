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
    case firstRun
    /// The shared result screen shown after any game completes.
    /// Carries the `GameResult` so the view can display rank, time, and mistakes.
    /// Games in M5+ push this route on session completion.
    case gameResult(GameResult)

    /// "VoiceOver required" interstitial shown when a user attempts to start a game
    /// with VoiceOver disabled. Carries the intended `GameKind` so the interstitial
    /// can offer the correct follow-up once the user enables VoiceOver.
    case voiceOverInterstitial(kind: GameKind)
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
    /// M4 will inject `StorageComponent` to conditionally return `.firstRun`
    /// when the "Basics completed" flag is absent.
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
}
