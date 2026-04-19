import SwiftUI
import RA11yCore

/// Deterministic root view used by screenshot automation.
///
/// When the app launches with `-screenshotScene <sceneID>`, `RA11y_iOSApp` bypasses
/// the normal startup router and renders this view instead. That removes onboarding,
/// VoiceOver gating, and navigation timing from the screenshot path.
struct iOSScreenshotRootView: View {

    /// The scene to render.
    let scene: iOSScreenshotScene

    @State private var router = iOSAppRouter()
    @State private var storage = UserDefaultsStorageComponent()

    var body: some View {
        NavigationStack(path: $router.path) {
            sceneView
        }
        .environment(router)
    }

    @ViewBuilder
    private var sceneView: some View {
        switch scene {
        case .hub:
            iOSHubView()
        case .voRequired:
            iOSVORequiredView(kind: .findAndFocus)
        case .firstRun:
            iOSFirstRunView(mode: .entry, storage: storage)
        case .enchanterPrologue,
             .enchanterAttempt,
             .enchanterRising,
             .enchanterTimed:
            iOSEnchantersTrialView(storage: storage, screenshotScene: scene)
        case .dungeonPrologue,
             .dungeonFirstAttempt:
            iOSDungeonDescentView(storage: storage, screenshotScene: scene)
        case .enchanterResult:
            iOSGameResultView(
                presenter: GameResultPresenter(result: enchanterResult),
                gameKind: .findAndFocus,
                gameSpecificAnnouncement: String(localized: "simon.results.legendary"),
                onPlayAgain: {},
                onReturnToHub: {}
            )
        case .dungeonResult:
            iOSGameResultView(
                presenter: GameResultPresenter(result: dungeonResult),
                gameKind: .scrollHunt,
                gameSpecificAnnouncement: String(localized: "dungeon.results.legendary"),
                onPlayAgain: {},
                onReturnToHub: {}
            )
        case .resonanceMockup:
            iOSDungeonResonanceMockupView()
        }
    }

    /// Sample Enchanter result used for deterministic screenshot capture.
    private var enchanterResult: GameResult {
        GameResult(
            gameID: "find-and-focus",
            rank: .perfect,
            timeSeconds: 8.4,
            mistakes: 0
        )
    }

    /// Sample Crystal Resonance (`scroll-hunt`) result used for deterministic screenshot capture.
    private var dungeonResult: GameResult {
        GameResult(
            gameID: "scroll-hunt",
            rank: .perfect,
            timeSeconds: 18.7,
            mistakes: 0
        )
    }
}
