import os
import SwiftUI
import RA11yCore

/// App entry point for RA11y on iOS.
///
/// `iOSRootView` owns the navigation router and provides it to the SwiftUI
/// view hierarchy. All routing decisions flow through `iOSAppRouter`.
///
/// ## Startup Logging
/// `init` logs the cold-start moment — the earliest instrumentation point in
/// the process. Subsequent milestones are logged in `iOSRootView` and
/// `HubViewModel`. Filter Console.app by:
///   subsystem = com.showblender.RA11y, category = startup
///
/// ## Screenshot Testing
/// The fastlane `screenshots` lane launches the app with specific arguments:
/// - `-screenshotResetOnboarding`: clears first-run flags → routes to First Run.
/// - `-screenshotMarkOnboardingComplete`: sets `basicsCompleted = true` → routes to hub.
/// - `-screenshotDirectTo{Game}`: pre-populates the navigation router's path in
///   `iOSRootView`'s `@State` initializer closure so the game view is present on the
///   first render. This file also sets `basicsCompleted = true` for those args so the
///   loading overlay resolves to hub promptly.
@main
struct RA11y_iOSApp: App {

    init() {
        RA11yLogger.startup.debug("Cold start — RA11y_iOSApp.init")
        applyScreenshotTestingOverridesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            iOSRootView()
        }
    }

    // MARK: - Screenshot Testing

    /// Applies `UserDefaults` overrides requested by the fastlane screenshot lane.
    ///
    /// Recognised launch arguments (all require `-uiTesting`):
    /// - `-screenshotResetOnboarding`: erases both first-run flags so the app routes
    ///   to the First Run entry screen. Used by `testScreenshots_FirstRun`.
    /// - `-screenshotMarkOnboardingComplete`: writes `basicsCompleted = true` so the
    ///   app routes directly to the hub. Used by `testScreenshots_Hub_VORequired` to
    ///   ensure a deterministic hub route regardless of prior simulator state (e.g.
    ///   after `testScreenshots_FirstRun` clears the flags in the same xcodebuild run).
    ///
    /// This function is a no-op in non-DEBUG builds and when `-uiTesting` is absent.
    ///
    /// - Concurrency: Called synchronously on `@main` during `init`. Safe because
    ///   `UserDefaultsStorageComponent` is not yet initialised at this point, so
    ///   there is no actor isolation conflict.
    private func applyScreenshotTestingOverridesIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting") else { return }

        if args.contains("-screenshotResetOnboarding") {
            UserDefaults.standard.removeObject(
                forKey: UserDefaultsStorageComponent.ScreenshotTestingKeys.basicsCompleted
            )
            UserDefaults.standard.removeObject(
                forKey: UserDefaultsStorageComponent.ScreenshotTestingKeys.basicsDismissed
            )
            RA11yLogger.startup.debug("Screenshot: onboarding flags cleared for first-run screen")
        }

        if args.contains("-screenshotMarkOnboardingComplete") {
            UserDefaults.standard.set(
                true,
                forKey: UserDefaultsStorageComponent.ScreenshotTestingKeys.basicsCompleted
            )
            RA11yLogger.startup.debug("Screenshot: basicsCompleted set for hub route")
        }

        // Direct-to-game screenshot args: ensure the hub is the base route so
        // the loading overlay resolves to hub (not first-run) while `iOSRootView`'s
        // `@State router` — which has the game destination pre-populated in its path
        // via its initializer closure — is unblocked quickly.
        // Any new game-direct arg should be listed here alongside -screenshotMarkOnboardingComplete.
        let directGameArgs = ["-screenshotDirectToEnchanter", "-screenshotDirectToRogue", "-screenshotDirectToDungeon"]
        if directGameArgs.contains(where: { args.contains($0) }) {
            UserDefaults.standard.set(
                true,
                forKey: UserDefaultsStorageComponent.ScreenshotTestingKeys.basicsCompleted
            )
            RA11yLogger.startup.debug("Screenshot: basicsCompleted set for direct-game route")
        }
        #endif
    }
}
