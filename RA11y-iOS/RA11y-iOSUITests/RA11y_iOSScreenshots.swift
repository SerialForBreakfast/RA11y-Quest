//
//  RA11y_iOSScreenshots.swift
//  RA11y-iOSUITests
//
//  Screenshot capture for the `fastlane ios screenshots` lane.
//
//  Xcode 16 changed xcresult bundle storage: screenshots are no longer plain
//  PNGs inside the bundle — they are zstd-compressed blobs. `fastlane snapshot`
//  (which relied on SnapshotHelper) cannot extract them. This file captures
//  screenshots as `XCTAttachment` objects with `.keepAlways` lifetime; the
//  fastlane lane runs `scripts/extract_screenshots.sh` after the test to
//  extract them via `xcrun xcresulttool export attachments`.
//

import XCTest

/// UITest suite that captures Hub screenshots as persistent XCT attachments.
///
/// Run via `fastlane ios screenshots`, not directly in Xcode's test runner.
/// Each `captureScreenshot(_:)` call stores a `keepAlways` PNG attachment
/// inside the xcresult bundle, which is later extracted by the lane.
final class RA11y_iOSScreenshots: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app and captures the Hub screen.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions must run on
    ///   the main thread. Called by the test runner on the main actor.
    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Choose Your Trial, Adventurer"].waitForExistence(timeout: 5),
            "Hub greeting did not appear. Expected the hub to be visible for screenshots."
        )
        captureScreenshot("01_Hub")

        let enchantersTrialCard = app.buttons["questCard.find-and-focus"]
        XCTAssertTrue(
            enchantersTrialCard.waitForExistence(timeout: 5),
            "Enchanter's Trial card did not appear on the hub."
        )
        enchantersTrialCard.tap()

        XCTAssertTrue(
            app.otherElements["enchanter.trial"].waitForExistence(timeout: 5),
            "Enchanter's Trial screen did not appear."
        )
        captureScreenshot("02_EnchantersTrial")
    }

    // MARK: - Private

    /// Captures the current screen as a `keepAlways` PNG attachment.
    ///
    /// The attachment name becomes the suggested human-readable filename in the
    /// xcresult manifest, used by `extract_screenshots.sh` when renaming.
    ///
    /// - Parameter name: Base filename without extension (e.g. `"01_Hub"`).
    /// - Concurrency: Must be called on `@MainActor`; `XCUIScreen.main` is
    ///   a UI API that requires the main thread.
    @MainActor
    private func captureScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(
            uniformTypeIdentifier: "public.png",
            name: "\(name).png",
            payload: screenshot.pngRepresentation,
            userInfo: nil
        )
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
