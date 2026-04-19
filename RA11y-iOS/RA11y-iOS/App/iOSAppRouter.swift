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
    /// Game 3 — Crystal Resonance (Scroll Hunt). Implemented in M7.
    case dungeonDescent
    /// Crystal Resonance v2 prototype route for iterative design and feedback integration.
    case dungeonResonancePrototype
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

    /// `true` while the player is progressing through the M4 guided Basics sequence.
    ///
    /// Set by `iOSBasicsSequenceView` before pushing each game route.
    /// Read by `iOSGameResultView` to show the "Continue Basics" CTA instead of
    /// the normal "Try Again" / "Return to Hub" buttons.
    /// Cleared when the sequence completes or is exited.
    var isInBasicsSequence: Bool = false

    /// Signals that the player tapped "Continue Basics" on the result screen.
    ///
    /// Set inside `popForBasicsContinue()` and consumed (cleared) by
    /// `iOSBasicsSequenceView.onAppear`. Distinguishes a successful step completion
    /// from back-navigation mid-game, preventing premature index advancement.
    var basicsStepCompleted: Bool = false

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

    /// Pops the result screen and the completed game back to `iOSBasicsSequenceView`.
    ///
    /// Called by the "Continue Basics" button on `iOSGameResultView`.
    /// Sets `basicsStepCompleted = true` before removing two levels so that the
    /// sequence view's `.onAppear` can distinguish this return from back-navigation.
    func popForBasicsContinue() {
        guard path.count >= 2 else { return }
        basicsStepCompleted = true
        path.removeLast(2)
        RA11yLogger.navigation.debug("Basics step complete. Stack depth: \(self.path.count)")
    }

    // MARK: - First-Run Routing

    /// Resolves the initial route based on stored Basics flags.
    ///
    /// - Parameter storage: Persistence layer for first-run flags.
    /// - Returns: `.firstRun(mode: .entry)` when neither flag is set; otherwise `.hub`.
    func resolveInitialRoute(using storage: any StorageComponent) async -> AppRoute {
        let snapshot = await storage.basicsProgressSnapshot()
        if snapshot.isCompleted { return .hub }
        if snapshot.isDismissed { return .hub }
        return .firstRun(mode: .entry)
    }
}
