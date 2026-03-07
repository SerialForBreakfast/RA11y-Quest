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
/// - `-screenshotResetOnboarding`: clears first-run flags so the app routes to
///   the First Run entry screen. Used by the screenshot test to capture that screen.
/// - Omitting the flag: preserves any stored state; typically the hub is shown
///   (first-run flags are set by an earlier test pass).
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
    /// - `-screenshotResetOnboarding`: erases the "basics completed / dismissed"
    ///   flags so `iOSRootView` routes to the First Run entry screen on next launch.
    ///
    /// This function is a no-op in non-DEBUG builds and when the relevant launch
    /// arguments are absent.
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
        #endif
    }
}
