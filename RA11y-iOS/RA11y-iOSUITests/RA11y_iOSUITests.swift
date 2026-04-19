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

    /// Verifies `RA11y_iOSApp.applyScreenshotTestingOverridesIfNeeded()` clears Lights Off
    /// when `-uiTesting` is combined with `-screenshotMarkOnboardingComplete`, so hub
    /// screenshots and automation stay deterministic.
    ///
    /// - Important: Requires the hub route (`hub.dmGreeting`, `hub.lightsOff.toggle`).
    @MainActor
    func testScreenshotLaunchArgsResetLightsOffToggle() throws {
        let app = XCUIApplication()

        app.launchArguments = ["-uiTesting", "-screenshotMarkOnboardingComplete"]
        app.launch()

        let greeting = app.descendants(matching: .any)["hub.dmGreeting"]
        XCTAssertTrue(
            greeting.waitForExistence(timeout: 15),
            "Hub greeting should appear when basics are marked complete"
        )

        let lightsOff = lightsOffToggleElement(in: app)
        XCTAssertTrue(
            lightsOff.waitForExistence(timeout: 5),
            "Lights Off toggle should be on the hub"
        )

        if lightsOffToggleIsOn(lightsOff) == false {
            lightsOff.tap()
        }
        XCTAssertTrue(
            lightsOffToggleIsOn(lightsOff),
            "Lights Off should be on after toggling"
        )

        app.terminate()

        app.launchArguments = ["-uiTesting", "-screenshotMarkOnboardingComplete"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["hub.dmGreeting"].waitForExistence(timeout: 15))

        let lightsOffAfterRelaunch = lightsOffToggleElement(in: app)
        XCTAssertTrue(lightsOffAfterRelaunch.waitForExistence(timeout: 5))
        XCTAssertFalse(
            lightsOffToggleIsOn(lightsOffAfterRelaunch),
            "Screenshot-style launch should clear Lights Off (toggle off)"
        )
    }

    /// Resolves the hub Lights Off control. SwiftUI usually maps `Toggle` to a `Switch` element.
    private func lightsOffToggleElement(in app: XCUIApplication) -> XCUIElement {
        let switches = app.switches.matching(identifier: "hub.lightsOff.toggle")
        if switches.count > 0 {
            return switches.firstMatch
        }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "hub.lightsOff.toggle"))
            .firstMatch
    }

    /// Interprets a switch-like element’s value (`"0"` / `"1"`) as off/on.
    private func lightsOffToggleIsOn(_ element: XCUIElement) -> Bool {
        guard let raw = element.value as? String else { return false }
        return raw == "1"
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
