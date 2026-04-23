//
//  RA11y_iOSScreenshots.swift
//  RA11y-iOSUITests
//
//  Screenshot capture for the `fastlane ios screenshots` lane.
//
//  Xcode 16 changed xcresult bundle storage: screenshots are no longer plain
//  PNGs inside the bundle; they are stored as xcresult attachments. This test
//  suite captures screenshots as `XCTAttachment` objects with `.keepAlways`
//  lifetime, and the fastlane lane extracts them afterward via
//  `scripts/extract_screenshots.sh`.
//
//  ## Screens Captured
//  | File                  | Scene ID             | Root Anchor          |
//  |-----------------------|----------------------|----------------------|
//  | 01_Hub                | hub                  | hub.dmGreeting       |
//  | 02_VORequired         | voRequired           | voRequired.title     |
//  | 03_FirstRun           | firstRun             | firstRun.title       |
//  | 04_EnchanterPrologue  | enchanterPrologue    | enchanter.prologue   |
//  | 05_EnchanterAttempt   | enchanterAttempt     | enchanter.attempt    |
//  | 06_EnchanterRising    | enchanterRising      | enchanter.rising     |
//  | 07_EnchanterTimed     | enchanterTimed       | enchanter.timed      |
//  | 08_EnchanterResult    | enchanterResult      | gameResult.root      |
//  | 09_DungeonPrologue    | dungeonPrologue      | dungeon.prologue     |
//  | 10_DungeonL1          | dungeonFirstAttempt  | dungeon.firstAttempt |
//  | 11_DungeonResult      | dungeonResult        | gameResult.root      |
//  | 12_ResonanceMockup    | resonanceMockup      | resonance.mockup.root  |
//  | 13_BanishmentPrologue | banishmentPrologue   | banishment.prologue    |
//  | 14_BanishmentWardTrap | banishmentWardTrap   | banishment.trap.root   |
//  | 15_BanishmentTower    | banishmentTower      | banishment.trap.root   |
//  | 16_BanishmentResult   | banishmentResult     | gameResult.root        |
//
//  ## Navigation Strategy
//  Screenshot capture now uses deterministic app-level scene bootstrapping:
//  `-uiTesting -screenshotScene <sceneID>`.
//
//  The app renders the requested scene directly via `iOSScreenshotRootView`, so
//  screenshot tests no longer depend on onboarding state, hub navigation, or
//  game progression taps in order to reach the requested screen.
//

import XCTest

/// UITest suite that captures all committed screenshots as persistent XCT attachments.
///
/// Run via `fastlane ios screenshots`, not directly in Xcode's test runner.
/// Each `captureScreenshot(_:)` call stores a `keepAlways` PNG attachment inside the
/// xcresult bundle, which is later extracted by the lane.
final class RA11y_iOSScreenshots: XCTestCase {

    override func setUpWithError() throws {
        // Keep screenshot runs resilient: one missing scene should not prevent later captures.
        continueAfterFailure = true
    }

    // MARK: - Pass 1: Hub + VoiceOver Required

    /// Captures the Hub and VoiceOver Required screens using deterministic scene boots.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Hub_VORequired() {
        let app = XCUIApplication()
        captureScene("hub", fileName: "01_Hub", anchorIdentifier: "hub.dmGreeting", in: app)
        captureScene("voRequired", fileName: "02_VORequired", anchorIdentifier: "voRequired.title", in: app)
    }

    // MARK: - Pass 2: First Run

    /// Captures the First Run entry screen using a deterministic scene boot.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_FirstRun() {
        let app = XCUIApplication()
        captureScene("firstRun", fileName: "03_FirstRun", anchorIdentifier: "firstRun.title", in: app)
    }

    // MARK: - Pass 3: Enchanter

    /// Captures the Enchanter screens using deterministic scene boots.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Enchanter() {
        let app = XCUIApplication()
        captureScene("enchanterPrologue", fileName: "04_EnchanterPrologue", anchorIdentifier: "enchanter.prologue", in: app)
        captureScene("enchanterAttempt", fileName: "05_EnchanterAttempt", anchorIdentifier: "enchanter.attempt", in: app)
        captureScene("enchanterRising", fileName: "06_EnchanterRising", anchorIdentifier: "enchanter.rising", in: app)
        captureScene("enchanterTimed", fileName: "07_EnchanterTimed", anchorIdentifier: "enchanter.timed", in: app)
        captureScene("enchanterResult", fileName: "08_EnchanterResult", anchorIdentifier: "gameResult.root", in: app)
    }

    // MARK: - Pass 4: Crystal Resonance (scroll hunt; `dungeon*` scene IDs)

    /// Captures the Crystal Resonance gameplay screens using deterministic scene boots.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Dungeon() {
        let app = XCUIApplication()
        captureScene("dungeonPrologue", fileName: "09_DungeonPrologue", anchorIdentifier: "dungeon.prologue", in: app)
        captureScene("dungeonFirstAttempt", fileName: "10_DungeonL1", anchorIdentifier: "dungeon.firstAttempt", in: app)
        captureScene("dungeonResult", fileName: "11_DungeonResult", anchorIdentifier: "gameResult.root", in: app)
    }

    // MARK: - Pass 5: Crystal Resonance mockup

    /// Captures the Resonance v2 design mockup using a deterministic scene boot.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_ResonanceMockup() {
        let app = XCUIApplication()
        captureScene("resonanceMockup", fileName: "12_ResonanceMockup", anchorIdentifier: "resonance.mockup.root", in: app)
    }

    // MARK: - Pass 6: The Banishment

    /// Captures Banishment lesson, practice trap, timed beat, and result using deterministic scene boots.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Banishment() {
        let app = XCUIApplication()
        captureScene("banishmentPrologue", fileName: "13_BanishmentPrologue", anchorIdentifier: "banishment.prologue", in: app)
        captureScene("banishmentWardTrap", fileName: "14_BanishmentWardTrap", anchorIdentifier: "banishment.trap.root", in: app)
        captureScene("banishmentTower", fileName: "15_BanishmentTower", anchorIdentifier: "banishment.trap.root", in: app)
        captureScene("banishmentResult", fileName: "16_BanishmentResult", anchorIdentifier: "gameResult.root", in: app)
    }

    // MARK: - Private

    /// Captures the current screen as a `keepAlways` PNG attachment.
    ///
    /// The attachment name becomes the suggested human-readable filename in the
    /// xcresult manifest, used by `extract_screenshots.sh` when renaming.
    ///
    /// - Parameter name: Base filename without extension (for example, `"01_Hub"`).
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

    /// Launches a deterministic screenshot scene and captures it once its root anchor exists.
    ///
    /// - Parameters:
    ///   - scene: Scene identifier consumed by `-screenshotScene`.
    ///   - fileName: PNG basename to attach.
    ///   - anchorIdentifier: Stable accessibility identifier expected at the scene root.
    ///   - app: Shared application handle for relaunching between scenes.
    ///   - timeout: Maximum wait for the root anchor to appear.
    /// - Concurrency: `@MainActor` because it drives XCUIApplication and screenshot APIs.
    @MainActor
    private func captureScene(
        _ scene: String,
        fileName: String,
        anchorIdentifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 8
    ) {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-screenshotScene", scene]
        app.launch()

        let anchor = app.descendants(matching: .any)[anchorIdentifier]
        XCTAssertTrue(
            anchor.waitForExistence(timeout: timeout),
            "Screenshot scene \(scene) failed to render anchor \(anchorIdentifier)"
        )
        guard anchor.exists else { return }
        captureScreenshot(fileName)
    }
}
