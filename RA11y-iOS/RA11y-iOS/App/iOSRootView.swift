import os
import SwiftUI
import RA11yCore

/// Root view of the RA11y iOS app.
///
/// Owns `iOSAppRouter` and `UserDefaultsStorageComponent`, providing both to the
/// view hierarchy via the SwiftUI environment. All navigation is driven through
/// the router's `NavigationPath`.
///
/// ## Startup Rendering
/// `iOSLaunchLoadingView` (torchlit hall / crystal shaft art) is shown until initial route
/// resolution completes. This avoids constructing the full hub, its background image, and
/// storage-backed refresh work during cold start.
///
/// ## Startup Logging
/// - `rootView.body` — first render, scene visible to the user.
/// - `routeResolution` — signpost interval covering the startup storage read
///   that determines whether to show the first-run flow.
///
/// ## Screenshot Testing
/// The fastlane `screenshots` lane launches the app with specific arguments:
/// - `-screenshotResetOnboarding`: clears first-run flags → routes to First Run.
/// - `-screenshotMarkOnboardingComplete`: sets `basicsCompleted = true` → routes to hub.
/// - `-screenshotDirectTo{Game}`: pre-populates `router.path` via the `@State` initializer
///   closure so the game view is on the NavigationStack from the very first render.
///   `RA11y_iOSApp.init()` also sets `basicsCompleted = true` for these args so the
///   loading overlay resolves to hub (not first-run) and is removed promptly.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRootView: View {

    // MARK: - State

    /// Navigation router pre-populated with a direct game route when the fastlane screenshot
    /// lane launches with a `-screenshotDirectTo*` argument. Pre-populating the path in the
    /// `@State` initializer ensures the game destination is present on the NavigationStack's
    /// first render — avoiding a race between the async `resolveInitialRouteIfNeeded()` task
    /// and SwiftUI's layout pass.
    ///
    /// In all non-screenshot launches the router is created with an empty path (normal flow).
    @State private var router: iOSAppRouter = {
        let router = iOSAppRouter()
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTesting") {
            if args.contains("-screenshotDirectToEnchanter") {
                router.pushGame(kind: .findAndFocus)
            } else if args.contains("-screenshotDirectToDungeon") {
                router.pushGame(kind: .scrollHunt)
            }
        }
        #endif
        return router
    }()
    @State private var storage = UserDefaultsStorageComponent()
    @State private var hasResolvedInitialRoute = false

    // MARK: - Body

    var body: some View {
        Group {
            if hasResolvedInitialRoute {
                NavigationStack(path: $router.path) {
                    iOSHubView(storage: storage)
                        .navigationDestination(for: AppRoute.self) { route in
                            routeDestination(for: route)
                        }
                }
                .environment(router)
            } else {
                loadingView
            }
        }
        .task {
            await resolveInitialRouteIfNeeded()
        }
    }

    // MARK: - Route Destinations

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .hub:
            iOSHubView(storage: storage)
        case .firstRun(let mode):
            iOSFirstRunView(mode: mode, storage: storage)
        case .enchantersTrial:
            iOSEnchantersTrialView(storage: storage)
        case .dungeonDescent:
            iOSDungeonDescentView(storage: storage)
        case .theBanishment:
            iOSBanishmentQuestView(storage: storage)
        case .arcanistsTower:
            iOSRotorNavigationQuestView(storage: storage)
        case .dungeonResonancePrototype:
            iOSDungeonResonanceMockupView()
        case .gameResult(let result, let gameKind, let gameSpecificAnnouncement):
            iOSGameResultView(
                presenter: GameResultPresenter(result: result),
                gameKind: gameKind,
                gameSpecificAnnouncement: gameSpecificAnnouncement,
                onPlayAgain: { restartGame(for: result) },
                onReturnToHub: { router.popToRoot() }
            )
        case .voiceOverInterstitial(let kind):
            iOSVORequiredView(kind: kind)
        }
    }

    /// Pops the result screen and restarts the correct game based on the result's game ID.
    ///
    /// Pops back through the navigation stack to the game entry point so the player
    /// can retry without returning all the way to the hub.
    private func restartGame(for result: GameResult) {
        router.popToRoot()
        guard let kind = gameKind(forGameID: result.gameID) else { return }
        router.pushGame(kind: kind)
    }

    /// Maps persisted ``GameResult/gameID`` strings to ``GameKind`` for replay routing.
    private func gameKind(forGameID gameID: String) -> GameKind? {
        switch gameID {
        case "find-and-focus": return .findAndFocus
        case "scroll-hunt": return .scrollHunt
        case "the-banishment": return .banishment
        case "arcanists-tower": return .arcanistsTower
        default: return nil
        }
    }

    // MARK: - First-Run Resolution

    /// Resolves the initial route once and updates navigation state.
    ///
    /// ## Startup Instrumentation
    /// Emits a `routeResolution` signpost interval covering the startup storage
    /// read that determines first-run routing. Visible in Instruments →
    /// "Points of Interest". If this interval is
    /// long (> ~50 ms) the storage actor or UserDefaults is the bottleneck.
    ///
    /// ## Screenshot Testing — Direct Route Override
    /// When launched with `-screenshotDirectToEnchanter` or `-screenshotDirectToDungeon`,
    /// the router's `path` is pre-populated by the `@State`
    /// initializer before this task even runs. This function does not touch the path for
    /// those scenarios — it only removes the loading overlay by setting `hasResolvedInitialRoute`.
    private func resolveInitialRouteIfNeeded() async {
        guard !hasResolvedInitialRoute else { return }

        let state = RA11yLogger.startupSignposter.beginInterval("routeResolution")
        defer { RA11yLogger.startupSignposter.endInterval("routeResolution", state) }

        let beginTag = RA11yLogger.startupTimestampTag()
        RA11yLogger.startup.debug("\(beginTag) routeResolution — async entry (before storage reads)")

        let wallStart = CFAbsoluteTimeGetCurrent()
        let initial = await router.resolveInitialRoute(using: storage)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - wallStart) * 1000

        if case .firstRun = initial {
            router.path = NavigationPath([initial])
        }
        hasResolvedInitialRoute = true

        // Announce to VoiceOver that the app has finished loading and is ready.
        // Passing `nil` lets VoiceOver focus the first element naturally (nav title).
        UIAccessibility.post(notification: .screenChanged, argument: nil)

        RA11yLogger.startup.debug("\(RA11yLogger.startupTimestampTag()) routeResolution complete — \(String(format: "%.1f", elapsedMs)) ms — initial route: \(String(describing: initial))")
    }

    /// Themed startup surface (guild hall / crystal shaft) shown before the initial route is known.
    private var loadingView: some View {
        iOSLaunchLoadingView()
            .onAppear {
                RA11yLogger.startup.debug("\(RA11yLogger.startupTimestampTag()) rootView.body — first render; awaiting route resolution")
                scheduleSlowLoadingAnnouncementIfStillPending()
            }
    }

    /// If route resolution takes longer than expected under the debugger, posts a
    /// VoiceOver announcement so the user knows the app is still working (not frozen).
    ///
    /// ## Concurrency
    /// Called from the loading overlay's `onAppear`. Spawns an unstructured `Task`
    /// that sleeps on the main actor; safe alongside `resolveInitialRouteIfNeeded`.
    private func scheduleSlowLoadingAnnouncementIfStillPending() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !hasResolvedInitialRoute else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: String(localized: "app.loading.still.a11yAnnouncement")
            )
            RA11yLogger.startup.debug("\(RA11yLogger.startupTimestampTag()) routeResolution still pending after 2 s — posted slow-loading announcement")
        }
    }
}

#Preview {
    iOSRootView()
}
