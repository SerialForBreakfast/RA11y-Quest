import os
import SwiftUI
import RA11yCore

/// Root view of the RA11y iOS app.
///
/// Owns `iOSAppRouter` and provides it to the view hierarchy via the SwiftUI
/// environment. All navigation is driven through the router's `NavigationPath`.
///
/// ## Startup Logging
/// Logs two milestones:
/// - `rootView.body` — first render, scene is visible to the user (ProgressView shown).
/// - `routeResolution` — signpost interval covering the async storage reads that
///   determine whether to show the hub or the first-run flow.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRootView: View {

    // MARK: - State

    @State private var router = iOSAppRouter()
    @State private var storage: UserDefaultsStorageComponent
    @State private var hubViewModel: HubViewModel
    @State private var hasResolvedInitialRoute = false

    // MARK: - Init

    init() {
        let storage = UserDefaultsStorageComponent()
        _storage = State(initialValue: storage)
        _hubViewModel = State(
            initialValue: HubViewModel(
                voiceOverProvider: iOSLiveVoiceOverStateProvider(),
                storage: storage
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if hasResolvedInitialRoute {
                    iOSHubView(viewModel: hubViewModel)
                } else {
                    ProgressView(String(localized: "app.loading"))
                        .onAppear {
                            RA11yLogger.startup.debug("rootView.body — first render; awaiting route resolution")
                        }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(for: route)
            }
        }
        .environment(router)
        .task {
            await resolveInitialRouteIfNeeded()
        }
    }

    // MARK: - Route Destinations

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .hub:
            iOSHubView(viewModel: hubViewModel)
        case .firstRun(let mode):
            iOSFirstRunView(mode: mode, storage: storage)
        case .gameResult(let result):
            iOSGameResultView(
                presenter: GameResultPresenter(result: result),
                onPlayAgain: { router.popToRoot() },   // M5+ will push the specific game route here
                onReturnToHub: { router.popToRoot() }
            )
        case .voiceOverInterstitial(let kind):
            iOSVORequiredView(kind: kind)
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
    }
}

#Preview {
    iOSRootView()
}
