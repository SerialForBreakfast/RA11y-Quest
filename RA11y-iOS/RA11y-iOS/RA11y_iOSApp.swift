import SwiftUI

/// App entry point for RA11y on iOS.
///
/// `iOSRootView` owns the navigation router and provides it to the SwiftUI
/// view hierarchy. All routing decisions flow through `iOSAppRouter`.
@main
struct RA11y_iOSApp: App {
    var body: some Scene {
        WindowGroup {
            iOSRootView()
        }
    }
}
