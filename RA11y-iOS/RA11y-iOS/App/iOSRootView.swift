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
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRootView: View {

    // MARK: - State

    @State private var router = iOSAppRouter()
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
                    .onAppear {
                        RA11yLogger.startup.debug("rootView.body — first render; awaiting route resolution")
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
        case .gameResult(let result, let gameSpecificAnnouncement):
            iOSGameResultView(
                presenter: GameResultPresenter(result: result),
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
    /// When launched with `-screenshotDirectToEnchanter`, the app pushes `.enchantersTrial`
    /// on top of the hub immediately after resolution. This allows the fastlane screenshot
    /// lane to capture the Enchanter's Trial L0 Prologue without requiring VoiceOver to be
    /// enabled in the simulator. Requires `-screenshotMarkOnboardingComplete` to be present
    /// so the hub (not first-run) is the initial route.
    private func resolveInitialRouteIfNeeded() async {
        guard !hasResolvedInitialRoute else { return }

        let state = RA11yLogger.startupSignposter.beginInterval("routeResolution")
        defer { RA11yLogger.startupSignposter.endInterval("routeResolution", state) }

        let initial = await router.resolveInitialRoute(using: storage)

        if case .firstRun = initial {
            router.path = NavigationPath([initial])
        }
        hasResolvedInitialRoute = true

        RA11yLogger.startup.debug("routeResolution complete — initial route: \(String(describing: initial))")

        // Screenshot testing: push a specific game screen directly on top of the hub
        // so the fastlane lane can capture game UI without needing VoiceOver enabled.
        // Only active when both -uiTesting and the specific direct-route flag are present.
        #if DEBUG
        applyScreenshotDirectRouteIfNeeded()
        #endif
    }

    /// Pushes a direct game route when the appropriate screenshot testing launch args are present.
    ///
    /// Each `if`-branch corresponds to one fastlane screenshot pass. As new games
    /// become screenshot-ready, add a new `else if` here and a matching test method
    /// in `RA11y_iOSScreenshots.swift`.
    ///
    /// - Concurrency: Must be called on `@MainActor`; mutates `router` which is `@MainActor`.
    #if DEBUG
    private func applyScreenshotDirectRouteIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting") else { return }

        if args.contains("-screenshotDirectToEnchanter") {
            router.push(.enchantersTrial)
        } else if args.contains("-screenshotDirectToRogue") {
            router.push(.roguesGauntlet)
        } else if args.contains("-screenshotDirectToDungeon") {
            router.push(.dungeonDescent)
        }
    }
    #endif
}

#Preview {
    iOSRootView()
}
