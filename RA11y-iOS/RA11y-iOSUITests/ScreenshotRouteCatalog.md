# Screenshot Route Catalog

This file is the single source of truth for screenshot coverage in the iOS UI test suite.

## Purpose
- Define the screens currently considered completed and required for fastlane export.
- Document the launch arguments, scene identifiers, root accessibility identifiers, and capture paths.
- Keep `RA11y_iOSScreenshots.swift`, `App/iOSScreenshotScene.swift`, and `fastlane/Fastfile` aligned.

## Required Screens (Current)

| File | Test Method | Launch Args | Scene ID | Anchor Identifier | Navigation Path |
|---|---|---|---|---|---|
| `01_Hub` | `testScreenshots_Hub_VORequired` | `-uiTesting -screenshotScene hub` | `hub` | `hub.dmGreeting` | Direct scene boot |
| `02_VORequired` | `testScreenshots_Hub_VORequired` | `-uiTesting -screenshotScene voRequired` | `voRequired` | `voRequired.title` | Direct scene boot |
| `03_FirstRun` | `testScreenshots_FirstRun` | `-uiTesting -screenshotScene firstRun` | `firstRun` | `firstRun.title` | Direct scene boot |
| `04_EnchanterPrologue` | `testScreenshots_Enchanter` | `-uiTesting -screenshotScene enchanterPrologue` | `enchanterPrologue` | `enchanter.prologue` | Direct scene boot |
| `05_EnchanterAttempt` | `testScreenshots_Enchanter` | `-uiTesting -screenshotScene enchanterAttempt` | `enchanterAttempt` | `enchanter.attempt` | Direct scene boot |
| `06_EnchanterRising` | `testScreenshots_Enchanter` | `-uiTesting -screenshotScene enchanterRising` | `enchanterRising` | `enchanter.rising` | Direct scene boot |
| `07_EnchanterTimed` | `testScreenshots_Enchanter` | `-uiTesting -screenshotScene enchanterTimed` | `enchanterTimed` | `enchanter.timed` | Direct scene boot |
| `08_EnchanterResult` | `testScreenshots_Enchanter` | `-uiTesting -screenshotScene enchanterResult` | `enchanterResult` | `gameResult.root` | Direct scene boot |
| `09_DungeonPrologue` | `testScreenshots_Dungeon` | `-uiTesting -screenshotScene dungeonPrologue` | `dungeonPrologue` | `dungeon.prologue` | Direct scene boot |
| `10_DungeonL1` | `testScreenshots_Dungeon` | `-uiTesting -screenshotScene dungeonFirstAttempt` | `dungeonFirstAttempt` | `dungeon.firstAttempt` | Direct scene boot |
| `11_DungeonResult` | `testScreenshots_Dungeon` | `-uiTesting -screenshotScene dungeonResult` | `dungeonResult` | `gameResult.root` | Direct scene boot |
| `13_BanishmentPrologue` | `testScreenshots_Banishment` | `-uiTesting -screenshotScene banishmentPrologue` | `banishmentPrologue` | `banishment.prologue` | Direct scene boot |
| `14_BanishmentWardTrap` | `testScreenshots_Banishment` | `-uiTesting -screenshotScene banishmentWardTrap` | `banishmentWardTrap` | `banishment.trap.root` | Direct scene boot |
| `15_BanishmentTower` | `testScreenshots_Banishment` | `-uiTesting -screenshotScene banishmentTower` | `banishmentTower` | `banishment.trap.root` | Direct scene boot |
| `16_BanishmentResult` | `testScreenshots_Banishment` | `-uiTesting -screenshotScene banishmentResult` | `banishmentResult` | `gameResult.root` | Direct scene boot |
| `17_FirstSpellEntry` | `testScreenshots_FirstSpell` | `-uiTesting -screenshotScene firstSpellEntry` | `firstSpellEntry` | `firstRun.title` | Direct scene boot |
| `18_FirstSpellVORequired` | `testScreenshots_FirstSpell` | `-uiTesting -screenshotScene firstSpellVORequired` | `firstSpellVORequired` | `firstSpellVORequired.title` | Direct scene boot |
| `19_FirstSpellReady` | `testScreenshots_FirstSpell` | `-uiTesting -screenshotScene firstSpellReady` | `firstSpellReady` | `firstSpell.ready.card` | Direct scene boot |
| `20_FirstSpellSuccess` | `testScreenshots_FirstSpell` | `-uiTesting -screenshotScene firstSpellSuccess` | `firstSpellSuccess` | `firstSpell.success.card` | Direct scene boot |

Screens `09`–`11` use legacy **`Dungeon*`** file basenames and `dungeon*` scene IDs for contract stability; in-app they present **Crystal Resonance** (Scroll Hunt).

## Deferred Screens
- Rogue screenshots remain deferred until the Rogue flow is stable enough for deterministic automation.

## UI integration tests (non-screenshot)

These tests live in `RA11y_iOSUITests.swift`. They do **not** attach PNGs and are **not** listed in the Fastfile screenshot allowlist. Run with `utility/build_and_test.sh --only-ios --include-ui-tests` (or `-only-testing` a single method).

| Purpose | Test method | Launch arguments | Anchor identifier |
|---|---|---|---|
| Screenshot-style launch with basics complete reaches hub greeting | `testScreenshotLaunchArgsReachHubWithBasicsComplete` | `-uiTesting` and `-screenshotMarkOnboardingComplete` | `hub.dmGreeting` |

`RA11y_iOSApp` removes the Lights Off UserDefaults key when those arguments are present; this test enables the toggle, terminates, relaunches with the same args, and asserts the toggle is off.

## Identifier Rules
- Every captured screen MUST have a stable root accessibility identifier.
- Screenshot tests MUST wait on the documented root anchor before attaching a PNG.
- Avoid text-based queries for navigation-critical capture checks.

## Fastlane Integration Contract
- `fastlane/Fastfile` must run only an allowlist of completed test methods.
- `fastlane/Fastfile` must fail if any screenshot listed in this file is missing after extraction.
- If a new screenshot test is added, update this file, `App/iOSScreenshotScene.swift`, and the Fastfile allowlist together in one commit.
