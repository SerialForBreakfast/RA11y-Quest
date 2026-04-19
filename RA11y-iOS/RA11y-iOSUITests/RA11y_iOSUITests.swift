//
//  RA11y_iOSUITests.swift
//  RA11y-iOSUITests
//
//  Created by Joseph McCraw on 2/19/26.
//

import XCTest

/// Non-screenshot UI tests (integration checks against the live app shell).
///
/// Screenshot capture lives in `RA11y_iOSScreenshots.swift`. This suite holds
/// behavioral tests that do not attach PNGs.
final class RA11y_iOSUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    /// Verifies `-uiTesting` with `-screenshotMarkOnboardingComplete` reaches the hub
    /// with a deterministic greeting (screenshot automation contract).
    ///
    /// - Important: Requires the hub route (`hub.dmGreeting`).
    @MainActor
    func testScreenshotLaunchArgsReachHubWithBasicsComplete() throws {
        let app = XCUIApplication()

        app.launchArguments = ["-uiTesting", "-screenshotMarkOnboardingComplete"]
        app.launch()

        let greeting = app.descendants(matching: .any)["hub.dmGreeting"]
        XCTAssertTrue(
            greeting.waitForExistence(timeout: 15),
            "Hub greeting should appear when basics are marked complete"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
