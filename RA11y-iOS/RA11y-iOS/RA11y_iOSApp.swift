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
@main
struct RA11y_iOSApp: App {

    /// Creates the app and applies UI-testing defaults when requested.
    init() {
        RA11yLogger.startup.debug("Cold start — RA11y_iOSApp.init")
        applyUITestingOverridesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            iOSRootView()
        }
    }

    private func applyUITestingOverridesIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        Task {
            await UserDefaultsStorageComponent().markBasicsDismissed()
        }
    }
}
