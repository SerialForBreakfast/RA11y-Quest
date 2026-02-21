import SwiftUI
import Testing
@testable import RA11y_iOS

// MARK: - M0: Router Tests

/// Tests for `iOSAppRouter` covering M0 acceptance criteria.
///
/// Verifies that the router initialises to the correct default state
/// and that navigation mutations behave predictably.
@MainActor
struct RouterTests {

    /// Router default state resolves to Hub (empty path = Hub is shown).
    ///
    /// Acceptance criterion: "Given a router initialized with default state,
    /// the initial route resolves to Hub."
    @Test func routerInitialRouteIsHub() {
        let router = iOSAppRouter()
        #expect(router.initialRoute == .hub)
        #expect(router.path.isEmpty)
    }

    /// Pushing a route increases stack depth.
    @Test func pushIncreasesDepth() {
        let router = iOSAppRouter()
        router.push(.firstRun)
        #expect(!router.path.isEmpty)
    }

    /// popToRoot resets the path regardless of stack depth.
    @Test func popToRootClearsPath() {
        let router = iOSAppRouter()
        router.push(.firstRun)
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    /// pop on an empty path is a no-op (does not crash).
    @Test func popOnEmptyPathIsNoOp() {
        let router = iOSAppRouter()
        router.pop() // must not crash or throw
        #expect(router.path.isEmpty)
    }
}
