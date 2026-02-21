import SwiftUI
import Testing
import RA11yCore
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

// MARK: - M2: VoiceOver Gating Tests

/// Tests for `GameStartDecision` → `AppRoute` mapping.
///
/// Validates TICKET-M2-VoiceOverStateProvider and TICKET-M2-VOOff-Interstitial
/// acceptance criteria: starting a game with VO OFF always routes to the interstitial.
@MainActor
struct VoiceOverGatingTests {

    /// Primary acceptance criterion: VO OFF → interstitial route.
    @Test func voiceOverOffRoutesToInterstitial() {
        let stub     = StubVoiceOverStateProvider(isVoiceOverRunning: false)
        let decision = GameStartDecision.evaluate(kind: .findAndFocus, provider: stub)

        guard case .requireVoiceOver(let kind) = decision else {
            Issue.record("Expected .requireVoiceOver, got \(decision)")
            return
        }

        // The hub maps this decision to .voiceOverInterstitial(kind:) — verify the route.
        let route = AppRoute.voiceOverInterstitial(kind: kind)
        #expect(route == .voiceOverInterstitial(kind: .findAndFocus))
    }

    /// VO ON → proceed decision (game route, added in M5).
    @Test func voiceOverOnProceeds() {
        let stub     = StubVoiceOverStateProvider(isVoiceOverRunning: true)
        let decision = GameStartDecision.evaluate(kind: .activateDoubleTap, provider: stub)
        #expect(decision == .proceed(kind: .activateDoubleTap))
    }

    /// Interstitial route can be pushed onto the navigation stack.
    @Test func interstitialRoutePushable() {
        let router = iOSAppRouter()
        router.push(.voiceOverInterstitial(kind: .scrollHunt))
        #expect(!router.path.isEmpty)
    }

    /// Gating applies to all three MVP game kinds, not just one.
    @Test func voiceOverOffGatesAllGameKinds() {
        let stub = StubVoiceOverStateProvider(isVoiceOverRunning: false)
        for kind in GameKind.allCases {
            let decision = GameStartDecision.evaluate(kind: kind, provider: stub)
            #expect(decision == .requireVoiceOver(kind: kind))
        }
    }
}
