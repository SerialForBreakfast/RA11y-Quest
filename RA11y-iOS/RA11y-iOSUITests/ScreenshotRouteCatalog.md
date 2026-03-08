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

## Deferred Screens
- Rogue screenshots remain deferred until the Rogue flow is stable enough for deterministic automation.

## Identifier Rules
- Every captured screen MUST have a stable root accessibility identifier.
- Screenshot tests MUST wait on the documented root anchor before attaching a PNG.
- Avoid text-based queries for navigation-critical capture checks.

## Fastlane Integration Contract
- `fastlane/Fastfile` must run only an allowlist of completed test methods.
- `fastlane/Fastfile` must fail if any screenshot listed in this file is missing after extraction.
- If a new screenshot test is added, update this file, `App/iOSScreenshotScene.swift`, and the Fastfile allowlist together in one commit.
