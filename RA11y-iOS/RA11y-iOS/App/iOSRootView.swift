import os
import SwiftUI
import RA11yCore

/// Root view of the RA11y iOS app.
///
/// Owns `iOSAppRouter` and `UserDefaultsStorageComponent`, providing both to the
/// view hierarchy via the SwiftUI environment. All navigation is driven through
/// the router's `NavigationPath`.
///
/// ## View Identity
/// `iOSHubView` is always the NavigationStack root — never conditionally swapped
/// for a `ProgressView`. Keeping the root structurally stable prevents SwiftUI from
/// losing `iOSHubView`'s `@State` (including `HubViewModel`) when the navigation
/// path changes. A translucent loading overlay is shown instead while the initial
/// route is being resolved (typically < one frame on device).
///
/// ## Startup Logging
/// - `rootView.body` — first render, scene visible to the user.
/// - `routeResolution` — signpost interval covering the two async storage reads
///   that determine whether to show the first-run flow.
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
                router.push(.enchantersTrial)
            } else if args.contains("-screenshotDirectToRogue") {
                router.push(.roguesGauntlet)
            } else if args.contains("-screenshotDirectToDungeon") {
                router.push(.dungeonDescent)
            }
        }
        #endif
        return router
    }()
    @State private var storage = UserDefaultsStorageComponent()
    @State private var hasResolvedInitialRoute = false

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $router.path) {
            iOSHubView()
                .navigationDestination(for: AppRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .environment(router)
        // Overlay a loading screen until route resolution completes.
        // Using an overlay (not a structural if/else) keeps iOSHubView's @State
        // stable across navigation changes, preventing spurious HubViewModel inits.
        .overlay {
            if !hasResolvedInitialRoute {
                ProgressView(String(localized: "app.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
                    // Gives VoiceOver a clear label while the app resolves its initial route.
                    .accessibilityLabel(String(localized: "app.loading.a11yLabel"))
                    .onAppear {
                        RA11yLogger.startup.debug("\(RA11yLogger.startupTimestampTag()) rootView.body — first render; awaiting route resolution")
                        scheduleSlowLoadingAnnouncementIfStillPending()
                    }
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
            iOSHubView()
        case .firstRun(let mode):
            iOSFirstRunView(mode: mode, storage: storage)
        case .enchantersTrial:
            iOSEnchantersTrialView(storage: storage)
        case .roguesGauntlet:
            iOSRogueGauntletView(storage: storage)
        case .dungeonDescent:
            iOSDungeonDescentView(storage: storage)
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
        switch result.gameID {
        case "find-and-focus":
            router.push(.enchantersTrial)
        case "rogue-gauntlet":
            router.push(.roguesGauntlet)
        case "scroll-hunt":
            router.push(.dungeonDescent)
        default:
            break
        }
    }

    // MARK: - First-Run Resolution

    /// Resolves the initial route once and updates navigation state.
    ///
    /// ## Startup Instrumentation
    /// Emits a `routeResolution` signpost interval covering the two async storage
    /// reads (`isBasicsCompleted` + `isBasicsDismissed`) that determine first-run
    /// routing. Visible in Instruments → "Points of Interest". If this interval is
    /// long (> ~50 ms) the storage actor or UserDefaults is the bottleneck.
    ///
    /// ## Screenshot Testing — Direct Route Override
    /// When launched with `-screenshotDirectToEnchanter` (or `-screenshotDirectToRogue` /
    /// `-screenshotDirectToDungeon`), the router's `path` is pre-populated by the `@State`
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
