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
//  ## Screens Captured
//  | File                  | Screen                           | Launch args                                       |
//  |-----------------------|----------------------------------|---------------------------------------------------|
//  | 01_Hub                | Game hub — VoiceOver OFF         | -uiTesting -screenshotMarkOnboardingComplete      |
//  | 02_VORequired         | VoiceOver Required interstitial  | navigated from hub (VO OFF)                       |
//  | 03_FirstRun           | First Run entry screen           | -uiTesting -screenshotResetOnboarding             |
//  | 04_EnchanterPrologue  | Enchanter's Trial L0 Prologue    | -uiTesting -screenshotDirectToEnchanter           |
//  | 05_DungeonPrologue    | Dungeon Descent L0 Prologue      | -uiTesting -screenshotDirectToDungeon             |
//  | 06_DungeonPlay        | Dungeon Descent L1 Play          | continue from direct route launch                 |
//  | 07_DungeonResult      | Shared result screen (Dungeon)   | activate target from L1                           |
//
//  ## Navigation Strategy
//  Screenshots that require navigation (VORequired) are obtained by interacting
//  with UI elements using stable `accessibilityIdentifier` values assigned in
//  each respective view. The test uses `waitForExistence(timeout:)` before every
//  interaction to handle async route resolution.
//
//  Game-specific screens (Enchanter, and future games) are captured by launching
//  with a `-screenshotDirectTo<Game>` arg. iOSRootView detects the arg and pushes
//  the game route on top of the hub automatically — no VoiceOver required.
//  To add a new game: add the arg to iOSRootView.applyScreenshotDirectRouteIfNeeded(),
//  RA11y_iOSApp.directGameArgs, and a new test method here.
//

import XCTest

/// UITest suite that captures all key screens as persistent XCT attachments.
///
/// Run via `fastlane ios screenshots`, not directly in Xcode's test runner.
/// Each `captureScreenshot(_:)` call stores a `keepAlways` PNG attachment
/// inside the xcresult bundle, which is later extracted by the lane.
///
/// ## Pass Structure
/// Capture is split into independent passes to isolate state across screens:
/// - `testScreenshots_Enchanter`:      Enchanter's Trial L0 Prologue (runs first alphabetically)
/// - `testScreenshots_Dungeon`:        Dungeon Descent L0 + L1 + result
/// - `testScreenshots_FirstRun`:       first-run entry screen (requires reset of onboarding state)
/// - `testScreenshots_Hub_VORequired`: hub and VoiceOver Required interstitial
///
/// The Fastfile's `UI_TEST_ID` targets the parent class
/// `RA11y-iOSUITests/RA11y_iOSScreenshots`, which runs both test methods in order.
final class RA11y_iOSScreenshots: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Pass 1: Hub → VoiceOver Required

    /// Captures the Hub and VoiceOver Required screens in a single app launch.
    ///
    /// `-screenshotMarkOnboardingComplete` ensures the hub is the initial route
    /// regardless of what a prior test method did to the simulator's UserDefaults.
    /// This is necessary because `testScreenshots_FirstRun` (which runs first,
    /// alphabetically) clears the onboarding flags via `-screenshotResetOnboarding`.
    ///
    /// VoiceOver is not active in the simulator, so tapping any quest card
    /// triggers the interstitial — no special routing is needed.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Hub_VORequired() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-screenshotMarkOnboardingComplete"]
        app.launch()

        // Wait for the hub's DM greeting to confirm the hub is fully rendered.
        let dmGreeting = app.staticTexts["hub.dmGreeting"]
        XCTAssertTrue(
            dmGreeting.waitForExistence(timeout: 8),
            "Hub DM greeting not found — route resolution may have timed out or failed"
        )

        captureScreenshot("01_Hub")

        // Tap the first quest card to trigger the VoiceOver Required interstitial.
        // VoiceOver is OFF in the simulator, so this always routes to VORequired.
        let firstCard = app.buttons["questCard.find-and-focus"]
        XCTAssertTrue(
            firstCard.waitForExistence(timeout: 5),
            "First quest card button not found (accessibilityIdentifier: questCard.find-and-focus)"
        )
        firstCard.tap()

        // Wait for the VoiceOver Required title to confirm navigation completed.
        let voTitle = app.staticTexts["voRequired.title"]
        XCTAssertTrue(
            voTitle.waitForExistence(timeout: 5),
            "VoiceOver Required title not found after tapping quest card"
        )

        captureScreenshot("02_VORequired")
    }

    // MARK: - Pass 2: First Run Entry Screen

    /// Captures the First Run entry screen.
    ///
    /// Launches with `-screenshotResetOnboarding` which clears the "basics
    /// completed / dismissed" flags in `UserDefaults`. `iOSRootView` then routes
    /// to `.firstRun(mode: .entry)` on startup rather than the hub.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_FirstRun() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-screenshotResetOnboarding"]
        app.launch()

        // Wait for the first-run title to confirm routing completed.
        let firstRunTitle = app.staticTexts["firstRun.title"]
        XCTAssertTrue(
            firstRunTitle.waitForExistence(timeout: 8),
            "First Run title not found — onboarding reset may not have taken effect"
        )

        captureScreenshot("03_FirstRun")
    }

    // MARK: - Pass 3: Enchanter's Trial — L0 Prologue

    /// Captures the Enchanter's Trial L0 Prologue screen.
    ///
    /// Launches with `-screenshotDirectToEnchanter`, which causes
    /// `RA11y_iOSApp.applyScreenshotTestingOverridesIfNeeded()` to set
    /// `basicsCompleted = true` and `iOSRootView.applyScreenshotDirectRouteIfNeeded()`
    /// to push `.enchantersTrial` on top of the hub.
    ///
    /// VoiceOver is not required — the L0 Prologue is always visible as the first
    /// screen of the game. The existing `enchanter.beginTrial` accessibility identifier
    /// on the "Begin Trial" button is used as a stable wait target.
    ///
    /// As new games become screenshot-ready, clone this method and swap the launch arg
    /// and wait target. Keep each game in its own `testScreenshots_` method so failures
    /// are isolated and partial captures still yield the passing game screens.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Enchanter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-screenshotDirectToEnchanter"]
        app.launch()

        // "Begin Trial" is the primary CTA on the L0 Prologue screen.
        // It appears only after the route is pushed and the view has rendered.
        let beginButton = app.buttons["enchanter.beginTrial"]
        XCTAssertTrue(
            beginButton.waitForExistence(timeout: 10),
            "Enchanter 'Begin Trial' button not found — direct route push may have failed"
        )

        captureScreenshot("04_EnchanterPrologue")
    }

    // MARK: - Pass 4: Dungeon Descent — L0 Prologue + L1 Play + Result

    /// Captures three Dungeon Descent screens in one deterministic launch:
    /// - L0 prologue
    /// - L1 play state
    /// - shared result screen after claiming the target
    ///
    /// Uses `-screenshotDirectToDungeon` so root routing pushes `.dungeonDescent`.
    /// The test performs a practice-zone scroll to enable "Begin Descent", then
    /// activates the guard-room target once it is reachable.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Dungeon() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-screenshotDirectToDungeon"]
        app.launch()

        let prologue = app.otherElements["dungeon.prologue"]
        XCTAssertTrue(
            prologue.waitForExistence(timeout: 10),
            "Dungeon prologue root not found — direct route push may have failed"
        )
        captureScreenshot("05_DungeonPrologue")

        let practiceZone = app.scrollViews["dungeon.practiceZone"]
        XCTAssertTrue(
            practiceZone.waitForExistence(timeout: 5),
            "Dungeon practice zone not found"
        )
        practiceZone.swipeUp()

        let beginButton = app.buttons["dungeon.beginDescent"]
        XCTAssertTrue(
            beginButton.waitForExistence(timeout: 5),
            "Dungeon 'Begin Descent' button not found"
        )
        XCTAssertTrue(beginButton.isEnabled, "Dungeon 'Begin Descent' should be enabled after practice scroll")
        beginButton.tap()

        let playRoot = app.otherElements["dungeon.play"]
        XCTAssertTrue(
            playRoot.waitForExistence(timeout: 8),
            "Dungeon play root not found after beginning descent"
        )
        captureScreenshot("06_DungeonPlay")

        app.swipeUp()

        let targetRoom = app.otherElements["dungeon.room.guard_room"]
        XCTAssertTrue(
            targetRoom.waitForExistence(timeout: 8),
            "Dungeon target room not found in L1"
        )
        targetRoom.tap()

        let resultRoot = app.otherElements["gameResult.root"]
        XCTAssertTrue(
            resultRoot.waitForExistence(timeout: 8),
            "Result screen not found after activating dungeon target"
        )
        captureScreenshot("07_DungeonResult")
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
