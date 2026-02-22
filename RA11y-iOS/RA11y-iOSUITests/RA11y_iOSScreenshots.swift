//
//  RA11y_iOSScreenshots.swift
//  RA11y-iOSUITests
//
//  Screenshot capture for fastlane snapshot.
//

import XCTest

final class RA11y_iOSScreenshots: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append("-uiTesting")
        app.launch()

        snapshot("01_Hub")
    }
}
