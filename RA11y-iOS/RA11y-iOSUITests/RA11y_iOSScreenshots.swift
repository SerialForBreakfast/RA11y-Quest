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
    //  | 05_EnchanterAttempt   | Enchanter L1 First Attempt       | successful path from L0                           |
    //  | 06_EnchanterRising    | Enchanter L2 Rising Challenge    | successful path from L1                           |
    //  | 07_EnchanterTimed     | Enchanter L3 Timed Trial         | successful path from L2                           |
    //  | 08_EnchanterResult    | Shared result screen (Enchanter) | successful target activation in L3                |
    //  | 09_RoguePrologue      | Rogue's Gauntlet L0 Prologue     | -uiTesting -screenshotDirectToRogue               |
    //  | 10_RogueL1            | Rogue L1 First Attempt           | successful path from L0                           |
    //  | 11_RogueL2            | Rogue L2 Rising Challenge        | successful path from L1                           |
    //  | 12_RogueL3            | Rogue L3 Timed Trial             | successful path from L2                           |
    //  | 13_RogueResult        | Shared result screen (Rogue)     | successful seal.passage tap in L3                 |
    //  | 14_DungeonPrologue    | Dungeon Descent L0 Prologue      | -uiTesting -screenshotDirectToDungeon             |
    //  | 15_DungeonL1          | Dungeon L1 First Attempt         | scroll + tap guard_room                           |
    //  | 16_DungeonL2          | Dungeon L2 Rising Challenge      | successful path from L1                           |
    //  | 17_DungeonL3          | Dungeon L3 Timed Trial           | successful path from L2                           |
    //  | 18_DungeonResult      | Shared result screen (Dungeon)   | successful ancient_vault claim in L3              |
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
/// - `testScreenshots_Enchanter`:      Enchanter happy path (L0 -> L3 -> result)
/// - `testScreenshots_Dungeon`:        Dungeon Descent L0 + L1 + result
/// - `testScreenshots_FirstRun`:       first-run entry screen (requires reset of onboarding state)
/// - `testScreenshots_Hub_VORequired`: hub and VoiceOver Required interstitial
///
/// The Fastfile's `UI_TEST_ID` targets the parent class
/// `RA11y-iOSUITests/RA11y_iOSScreenshots`, which runs all screenshot test methods.
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

    // MARK: - Pass 3: Enchanter's Trial — Happy Path (L0 -> L3 -> Result)

    /// Captures the Enchanter happy path across all main screens.
    ///
    /// Launches with `-screenshotDirectToEnchanter`, which causes
    /// `RA11y_iOSApp.applyScreenshotTestingOverridesIfNeeded()` to set
    /// `basicsCompleted = true` and `iOSRootView.applyScreenshotDirectRouteIfNeeded()`
    /// to push `.enchantersTrial` on top of the hub.
    ///
    /// VoiceOver is not required. Under `-uiTesting`, target selection is deterministic
    /// (first relic in each level), so this method can progress through L1/L2/L3
    /// and capture a successful result flow.
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

        let prologue = app.otherElements["enchanter.prologue"]
        XCTAssertTrue(
            prologue.waitForExistence(timeout: 10),
            "Enchanter prologue root not found — direct route push may have failed"
        )

        let beginButton = app.buttons["enchanter.beginTrial"]
        XCTAssertTrue(
            beginButton.waitForExistence(timeout: 10),
            "Enchanter 'Begin Trial' button not found — direct route push may have failed"
        )

        captureScreenshot("04_EnchanterPrologue")

        beginButton.tap()

        let attempt = app.otherElements["enchanter.attempt"]
        XCTAssertTrue(
            attempt.waitForExistence(timeout: 8),
            "Enchanter L1 attempt view not found"
        )
        captureScreenshot("05_EnchanterAttempt")

        let l1Target = app.buttons["enchanter.relic.dragon_scale"]
        XCTAssertTrue(
            l1Target.waitForExistence(timeout: 6),
            "Enchanter L1 target relic not found"
        )
        l1Target.tap()

        let l1Continue = app.buttons["enchanter.l1.continue"]
        XCTAssertTrue(
            l1Continue.waitForExistence(timeout: 6),
            "Enchanter L1 continue button not found after correct selection"
        )
        l1Continue.tap()

        let rising = app.otherElements["enchanter.rising"]
        XCTAssertTrue(
            rising.waitForExistence(timeout: 8),
            "Enchanter L2 rising view not found"
        )
        captureScreenshot("06_EnchanterRising")

        let l2Target = app.buttons["enchanter.relic.dragon_scale"]
        XCTAssertTrue(
            l2Target.waitForExistence(timeout: 6),
            "Enchanter L2 target relic not found"
        )
        l2Target.tap()

        let l2Continue = app.buttons["enchanter.l2.continue"]
        XCTAssertTrue(
            l2Continue.waitForExistence(timeout: 6),
            "Enchanter L2 continue button not found after correct selection"
        )
        l2Continue.tap()

        let timed = app.otherElements["enchanter.timed"]
        XCTAssertTrue(
            timed.waitForExistence(timeout: 8),
            "Enchanter L3 timed view not found"
        )
        captureScreenshot("07_EnchanterTimed")

        let l3Target = app.buttons["enchanter.relic.dragon_scale"]
        XCTAssertTrue(
            l3Target.waitForExistence(timeout: 6),
            "Enchanter L3 target relic not found"
        )
        l3Target.tap()

        let enchanterResult = app.otherElements["gameResult.root"]
        XCTAssertTrue(
            enchanterResult.waitForExistence(timeout: 8),
            "Enchanter result screen not found after successful L3 target activation"
        )
        captureScreenshot("08_EnchanterResult")
    }

    // MARK: - Pass 4: Rogue's Gauntlet — L0 Prologue + L1 + L2 + L3 + Result

    /// Captures Rogue's Gauntlet screens across all main game phases.
    ///
    /// Uses `-screenshotDirectToRogue` so the router's `path` is pre-populated with
    /// `.roguesGauntlet` before the first render. In UI-testing mode, `RogueSeal.setForL2()`
    /// and `setForL3()` return deterministic, ordered seal sets with `"passage"` as the
    /// first (target) seal — making `rogue.seal.passage` a stable activation target.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Rogue() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-screenshotDirectToRogue"]
        app.launch()

        let prologue = app.otherElements["rogue.prologue"]
        XCTAssertTrue(prologue.waitForExistence(timeout: 10), "Rogue prologue not found")
        captureScreenshot("09_RoguePrologue")

        let beginButton = app.buttons["rogue.beginTrial"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 5), "'Begin Trial' not found")
        beginButton.tap()

        // L1: single target seal — tap directly
        let l1Root = app.otherElements["rogue.firstAttempt"]
        XCTAssertTrue(l1Root.waitForExistence(timeout: 8), "Rogue L1 view not found")
        captureScreenshot("10_RogueL1")
        let l1Target = app.buttons["rogue.seal.passage"]
        XCTAssertTrue(l1Target.waitForExistence(timeout: 5), "L1 seal.passage not found")
        l1Target.tap()

        // L1 → L2: continue button
        let l1Continue = app.buttons["rogue.l1.continue"]
        XCTAssertTrue(l1Continue.waitForExistence(timeout: 6), "L1 continue not found")
        l1Continue.tap()

        // L2: tap the passage seal
        let l2Root = app.otherElements["rogue.rising"]
        XCTAssertTrue(l2Root.waitForExistence(timeout: 8), "Rogue L2 view not found")
        captureScreenshot("11_RogueL2")
        let l2Target = app.buttons["rogue.seal.passage"]
        XCTAssertTrue(l2Target.waitForExistence(timeout: 5), "L2 seal.passage not found")
        l2Target.tap()

        // L2 → L3: continue button
        let l2Continue = app.buttons["rogue.l2.continue"]
        XCTAssertTrue(l2Continue.waitForExistence(timeout: 6), "L2 continue not found")
        l2Continue.tap()

        // L3: tap the passage seal → result
        let l3Root = app.otherElements["rogue.timed"]
        XCTAssertTrue(l3Root.waitForExistence(timeout: 8), "Rogue L3 view not found")
        captureScreenshot("12_RogueL3")
        let l3Target = app.buttons["rogue.seal.passage"]
        XCTAssertTrue(l3Target.waitForExistence(timeout: 5), "L3 seal.passage not found")
        l3Target.tap()

        let resultRoot = app.otherElements["gameResult.root"]
        if resultRoot.waitForExistence(timeout: 10) {
            captureScreenshot("13_RogueResult")
        }
    }

    // MARK: - Pass 5: Dungeon Descent — L0 Prologue + L1 + L2 + L3 + Result

    /// Captures Dungeon Descent screens across all main game phases.
    ///
    /// Uses `-screenshotDirectToDungeon` to push `.dungeonDescent` on top of the hub.
    /// The test performs a practice scroll, progresses through L1 and L2 by scrolling to
    /// the target room in each level, then captures L3 and the result screen.
    ///
    /// - Concurrency: `@MainActor` — XCUIApplication interactions require the main thread.
    @MainActor
    func testScreenshots_Dungeon() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-screenshotDirectToDungeon"]
        app.launch()

        let prologue = app.otherElements["dungeon.prologue"]
        XCTAssertTrue(prologue.waitForExistence(timeout: 10), "Dungeon prologue not found")
        captureScreenshot("14_DungeonPrologue")

        let practiceZone = app.otherElements["dungeon.practiceZone"]
        XCTAssertTrue(practiceZone.waitForExistence(timeout: 5), "Practice zone not found")
        practiceZone.swipeUp()
        practiceZone.swipeUp()

        let beginButton = app.buttons["dungeon.beginDescent"]
        XCTAssertTrue(beginButton.waitForExistence(timeout: 5), "'Begin Descent' not found")
        XCTAssertTrue(beginButton.isEnabled, "'Begin Descent' should be enabled after practice scroll")
        beginButton.tap()

        // L1: scroll to guard_room → tap → continue
        let l1Root = app.otherElements["dungeon.firstAttempt"]
        XCTAssertTrue(l1Root.waitForExistence(timeout: 8), "Dungeon L1 view not found")
        captureScreenshot("15_DungeonL1")
        app.swipeUp()
        let l1Target = app.otherElements["dungeon.room.guard_room"]
        XCTAssertTrue(l1Target.waitForExistence(timeout: 8), "L1 guard_room not found")
        l1Target.tap()
        let l1Continue = app.buttons["dungeon.continue"]
        XCTAssertTrue(l1Continue.waitForExistence(timeout: 6), "L1 continue not found")
        l1Continue.tap()

        // L2: scroll to relic_vault → tap → continue
        let l2Root = app.otherElements["dungeon.rising"]
        XCTAssertTrue(l2Root.waitForExistence(timeout: 8), "Dungeon L2 view not found")
        captureScreenshot("16_DungeonL2")
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        let l2Target = app.otherElements["dungeon.room.relic_vault"]
        XCTAssertTrue(l2Target.waitForExistence(timeout: 8), "L2 relic_vault not found")
        l2Target.tap()
        let l2Continue = app.buttons["dungeon.continue"]
        XCTAssertTrue(l2Continue.waitForExistence(timeout: 6), "L2 continue not found")
        l2Continue.tap()

        // L3: scroll to ancient_vault → tap → result
        let l3Root = app.otherElements["dungeon.timed"]
        XCTAssertTrue(l3Root.waitForExistence(timeout: 8), "Dungeon L3 view not found")
        captureScreenshot("17_DungeonL3")
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        let l3Target = app.otherElements["dungeon.room.ancient_vault"]
        XCTAssertTrue(l3Target.waitForExistence(timeout: 8), "L3 ancient_vault not found")
        l3Target.tap()

        let resultRoot = app.otherElements["gameResult.root"]
        if resultRoot.waitForExistence(timeout: 10) {
            captureScreenshot("18_DungeonResult")
        }
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
