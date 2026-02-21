import SwiftUI
import RA11yCore

/// Root view of the RA11y iOS app.
///
/// Owns `iOSAppRouter` and provides it to the view hierarchy via the SwiftUI
/// environment. All navigation is driven through the router's `NavigationPath`.
///
/// ## Concurrency
/// Implicitly `@MainActor` via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
struct iOSRootView: View {

    // MARK: - State

    @State private var router = iOSAppRouter()

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $router.path) {
            iOSHubView()
                .navigationDestination(for: AppRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .environment(router)
    }

    // MARK: - Route Destinations

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .hub:
            iOSHubView()
        case .firstRun:
            // Placeholder — full implementation in M4.
            Text(String(localized: "placeholder.firstRun"))
                .font(.ra11yBody)
        case .gameResult(let result):
            iOSGameResultView(
                presenter: GameResultPresenter(result: result),
                onPlayAgain: { router.popToRoot() },   // M5+ will push the specific game route here
                onReturnToHub: { router.popToRoot() }
            )
        }
    }
}

#Preview {
    iOSRootView()
}
