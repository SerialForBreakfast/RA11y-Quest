import AppKit
import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Executive walkthrough tests that prove ScreenAuditKit against realistic generated UI screenshots.
final class ScreenAuditFeatureWalkthroughTests: XCTestCase {
    /// Proves a missing escape action in an iOS-style destructive alert is caught by OCR text rules.
    func testIOSAlertWalkthroughCatchesMissingCancelAction() throws {
        let pass = try makeFixture(named: "ios-alert-pass")
        try drawIOSAlert(includeCancel: true, to: pass.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "iOS Alert Walkthrough",
            screenID: "deleteAlert",
            filename: "screen.png",
            width: 390,
            height: 844,
            required: ["Cancel", "Delete"]
        ).write(to: pass.contractFile, atomically: true, encoding: .utf8)

        let passResult = try validate(fixture: pass, ocr: .vision)
        XCTAssertFalse(passResult.findingsReport.findings.contains { $0.ruleID == .requiredTextMissing })

        let fail = try makeFixture(named: "ios-alert-fail")
        try drawIOSAlert(includeCancel: false, to: fail.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "iOS Alert Walkthrough",
            screenID: "deleteAlert",
            filename: "screen.png",
            width: 390,
            height: 844,
            required: ["Cancel", "Delete"]
        ).write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let failResult = try validate(fixture: fail, ocr: .vision)
        XCTAssertTrue(failResult.findingsReport.findings.contains { $0.ruleID == .requiredTextMissing && $0.severity == .error })
        XCTAssertTrue(try summaryText(for: fail).contains("Required text `Cancel` was not found."))
    }

    /// Proves internal debug copy in a production settings panel is caught before screenshots ship.
    func testSettingsWalkthroughCatchesForbiddenDebugCopy() throws {
        let pass = try makeFixture(named: "settings-debug-pass")
        try drawSettingsPanel(includesDebugCopy: false, to: pass.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "Settings Walkthrough",
            screenID: "settings",
            filename: "screen.png",
            width: 390,
            height: 844,
            forbidden: ["DEBUG BUILD", "TODO"]
        ).write(to: pass.contractFile, atomically: true, encoding: .utf8)

        let passResult = try validate(fixture: pass, ocr: .vision)
        XCTAssertFalse(passResult.findingsReport.findings.contains { $0.ruleID == .forbiddenTextPresent })

        let fail = try makeFixture(named: "settings-debug-fail")
        try drawSettingsPanel(includesDebugCopy: true, to: fail.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "Settings Walkthrough",
            screenID: "settings",
            filename: "screen.png",
            width: 390,
            height: 844,
            forbidden: ["DEBUG BUILD", "TODO"]
        ).write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let failResult = try validate(fixture: fail, ocr: .vision)
        XCTAssertTrue(failResult.findingsReport.findings.contains { $0.ruleID == .forbiddenTextPresent && $0.severity == .error })
        XCTAssertTrue(try summaryText(for: fail).contains("forbiddenTextPresent"))
    }

    /// Proves no-OCR local validation is honest: text gates are skipped as info, not false failures.
    func testNoOCRWalkthroughReportsSkippedTextRules() throws {
        let fixture = try makeFixture(named: "no-ocr-skip")
        try drawIOSAlert(includeCancel: true, to: fixture.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "No OCR Walkthrough",
            screenID: "deleteAlert",
            filename: "screen.png",
            width: 390,
            height: 844,
            required: ["Cancel"],
            forbidden: ["DEBUG BUILD"]
        ).write(to: fixture.contractFile, atomically: true, encoding: .utf8)

        let result = try validate(fixture: fixture, ocr: .none)
        XCTAssertFalse(result.findingsReport.hasHardFailures)
        XCTAssertTrue(result.findingsReport.findings.contains { $0.ruleID == .textRulesSkipped && $0.severity == .info })
        XCTAssertTrue(try summaryText(for: fixture).contains("textRulesSkipped"))
    }

    /// Proves the wrong device or orientation cannot be silently accepted as a valid capture.
    func testWrongOrientationWalkthroughCatchesDeviceProfileMismatch() throws {
        let pass = try makeFixture(named: "device-orientation-pass")
        try drawIPhoneCommerceScreen(size: .portraitPhone, clippedMenu: false, to: pass.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "Device Profile Walkthrough",
            screenID: "checkout",
            filename: "screen.png",
            width: 390,
            height: 844
        ).write(to: pass.contractFile, atomically: true, encoding: .utf8)
        XCTAssertFalse(try validate(fixture: pass).findingsReport.hasHardFailures)

        let fail = try makeFixture(named: "device-orientation-fail")
        try drawIPhoneCommerceScreen(size: .landscapePhone, clippedMenu: true, to: fail.screenshots.appendingPathComponent("screen.png"))
        try contract(
            project: "Device Profile Walkthrough",
            screenID: "checkout",
            filename: "screen.png",
            width: 390,
            height: 844
        ).write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let result = try validate(fixture: fail)
        XCTAssertTrue(result.findingsReport.findings.contains { $0.ruleID == .dimensionMismatch && $0.severity == .error })
        XCTAssertTrue(try summaryText(for: fail).contains("844x390"))
    }

    /// Proves volatile regions can change while stable UI drift still fails.
    func testBaselineWalkthroughIgnoresClockButFlagsClippedCTA() throws {
        let volatileOnly = try makeFixture(named: "baseline-volatile-pass")
        try drawOnboardingCard(clippedCTA: false, clockVariant: true, to: volatileOnly.screenshots.appendingPathComponent("screen.png"))
        try drawOnboardingCard(clippedCTA: false, clockVariant: false, to: volatileOnly.baselines.appendingPathComponent("screen.png"))
        try baselineContract().write(to: volatileOnly.contractFile, atomically: true, encoding: .utf8)

        let volatileResult = try validate(fixture: volatileOnly, baselineDirectory: volatileOnly.baselines)
        XCTAssertFalse(volatileResult.findingsReport.findings.contains { $0.ruleID == .baselineDifferenceExceeded })

        let clipped = try makeFixture(named: "baseline-clipped-fail")
        try drawOnboardingCard(clippedCTA: true, clockVariant: true, to: clipped.screenshots.appendingPathComponent("screen.png"))
        try drawOnboardingCard(clippedCTA: false, clockVariant: false, to: clipped.baselines.appendingPathComponent("screen.png"))
        try baselineContract().write(to: clipped.contractFile, atomically: true, encoding: .utf8)

        let clippedResult = try validate(fixture: clipped, baselineDirectory: clipped.baselines)
        XCTAssertTrue(clippedResult.findingsReport.findings.contains { $0.ruleID == .baselineDifferenceExceeded && $0.severity == .warning })
        XCTAssertFalse(clippedResult.overlayPaths.isEmpty)
        XCTAssertTrue(try summaryText(for: clipped).contains("baselineDifferenceExceeded"))
    }

    /// Proves tvOS focus styling regressions can be caught by protected-region baseline comparison.
    func testTVFocusWalkthroughCatchesLostFocusRing() throws {
        let pass = try makeFixture(named: "tvos-focus-pass")
        try drawTVFocusScreen(hasFocusRing: true, to: pass.screenshots.appendingPathComponent("screen.png"))
        try drawTVFocusScreen(hasFocusRing: true, to: pass.baselines.appendingPathComponent("screen.png"))
        try tvFocusContract().write(to: pass.contractFile, atomically: true, encoding: .utf8)
        XCTAssertFalse(try validate(fixture: pass, baselineDirectory: pass.baselines).findingsReport.hasHardFailures)

        let fail = try makeFixture(named: "tvos-focus-fail")
        try drawTVFocusScreen(hasFocusRing: false, to: fail.screenshots.appendingPathComponent("screen.png"))
        try drawTVFocusScreen(hasFocusRing: true, to: fail.baselines.appendingPathComponent("screen.png"))
        try tvFocusContract().write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let failResult = try validate(fixture: fail, baselineDirectory: fail.baselines)
        XCTAssertTrue(failResult.findingsReport.findings.contains { $0.ruleID == .baselineDifferenceExceeded })
        XCTAssertTrue(try summaryText(for: fail).contains("baselineDifferenceExceeded"))
    }

    /// Proves desktop chrome regressions, such as a missing Help toolbar item, are caught by OCR text rules.
    func testMacToolbarWalkthroughCatchesMissingHelpItem() throws {
        let pass = try makeFixture(named: "mac-toolbar-pass")
        try drawMacWindowToolbar(includeHelp: true, to: pass.screenshots.appendingPathComponent("screen.png"))
        try macToolbarContract().write(to: pass.contractFile, atomically: true, encoding: .utf8)
        XCTAssertFalse(try validate(fixture: pass, ocr: .vision).findingsReport.hasHardFailures)

        let fail = try makeFixture(named: "mac-toolbar-fail")
        try drawMacWindowToolbar(includeHelp: false, to: fail.screenshots.appendingPathComponent("screen.png"))
        try macToolbarContract().write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let result = try validate(fixture: fail, ocr: .vision)
        XCTAssertTrue(result.findingsReport.findings.contains { $0.ruleID == .requiredTextMissing })
        XCTAssertTrue(try summaryText(for: fail).contains("Required text `Help` was not found."))
    }

    /// Proves visual artifact checks catch missing art, checkerboards, and alpha matte defects on realistic cards.
    func testVisualArtifactWalkthroughProducesFindingsAndOverlays() throws {
        let pass = try makeFixture(named: "visual-artifacts-pass")
        try drawArtworkCard(style: .healthyArt, to: pass.screenshots.appendingPathComponent("art.png"))
        try visualArtifactContract(filename: "art.png").write(to: pass.contractFile, atomically: true, encoding: .utf8)
        XCTAssertFalse(try validate(fixture: pass).findingsReport.findings.contains { $0.ruleID == .renderedMatteRisk || $0.ruleID == .checkerboardPatternRisk })

        let fail = try makeFixture(named: "visual-artifacts-fail")
        try drawArtworkCard(style: .flatMatte, to: fail.screenshots.appendingPathComponent("matte.png"))
        try drawArtworkCard(style: .checkerboard, to: fail.screenshots.appendingPathComponent("checker.png"))
        try writeOpaqueBorderAsset(to: fail.screenshots.appendingPathComponent("alpha.png"))
        try """
        {
          "schemaVersion": 1,
          "projectName": "Visual Artifact Walkthrough",
          "screens": [
            \(visualScreenJSON(id: "matte", filename: "matte.png")),
            \(visualScreenJSON(id: "checker", filename: "checker.png")),
            {
              "id": "alpha",
              "filename": "alpha.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ]
        }
        """.write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let result = try validate(fixture: fail)
        let ruleIDs = Set(result.findingsReport.findings.map(\.ruleID))
        XCTAssertTrue(ruleIDs.contains(.renderedMatteRisk))
        XCTAssertTrue(ruleIDs.contains(.checkerboardPatternRisk))
        XCTAssertTrue(ruleIDs.contains(.suspiciousOpaqueBorder))
        XCTAssertEqual(result.overlayPaths.count, 3)
    }

    /// Proves flow validation catches a generated journey where Ready appears without Permissions.
    func testFlowWalkthroughCatchesMissingPermissionsStep() throws {
        let pass = try makeFixture(named: "flow-completeness-pass")
        try drawFlowStep(title: "Welcome", subtitle: "Start setup", to: pass.screenshots.appendingPathComponent("01_Welcome.png"))
        try drawFlowStep(title: "Permissions", subtitle: "Grant access", to: pass.screenshots.appendingPathComponent("02_Permissions.png"))
        try drawFlowStep(title: "Ready", subtitle: "You are all set", to: pass.screenshots.appendingPathComponent("03_Ready.png"))
        try flowContract().write(to: pass.contractFile, atomically: true, encoding: .utf8)
        XCTAssertFalse(try validate(fixture: pass).findingsReport.hasHardFailures)

        let fail = try makeFixture(named: "flow-completeness-fail")
        try drawFlowStep(title: "Welcome", subtitle: "Start setup", to: fail.screenshots.appendingPathComponent("01_Welcome.png"))
        try drawFlowStep(title: "Ready", subtitle: "You are all set", to: fail.screenshots.appendingPathComponent("03_Ready.png"))
        try flowContract().write(to: fail.contractFile, atomically: true, encoding: .utf8)

        let result = try validate(fixture: fail)
        let ruleIDs = Set(result.findingsReport.findings.map(\.ruleID))
        XCTAssertTrue(ruleIDs.contains(.missingScreenshot))
        XCTAssertTrue(ruleIDs.contains(.flowMissingRequiredStep))
        XCTAssertTrue(ruleIDs.contains(.flowPreviousStepMissing))
        XCTAssertTrue(try String(contentsOf: fail.output.appendingPathComponent("flow-summary.md"), encoding: .utf8).contains("| 2 | permissions | yes | missing |"))
    }

    /// Proves a representative generated product flow produces clean reports.
    func testCleanHappyPathWalkthroughProducesNoFindings() throws {
        let fixture = try makeFixture(named: "clean-happy-path")
        try drawFlowStep(title: "Welcome", subtitle: "Start setup", to: fixture.screenshots.appendingPathComponent("01_Welcome.png"))
        try drawFlowStep(title: "Permissions", subtitle: "Grant access", to: fixture.screenshots.appendingPathComponent("02_Permissions.png"))
        try drawFlowStep(title: "Ready", subtitle: "You are all set", to: fixture.screenshots.appendingPathComponent("03_Ready.png"))
        try flowContract().write(to: fixture.contractFile, atomically: true, encoding: .utf8)

        let result = try validate(fixture: fixture)

        XCTAssertTrue(result.findingsReport.findings.isEmpty)
        XCTAssertTrue(try summaryText(for: fixture).contains("No findings."))
        XCTAssertTrue(try String(contentsOf: fixture.output.appendingPathComponent("flow-summary.md"), encoding: .utf8).contains("Release Onboarding"))
    }

    private func validate(
        fixture: WalkthroughFixture,
        ocr: ScreenAuditOCROption = .none,
        baselineDirectory: URL? = nil
    ) throws -> ScreenAuditValidationResult {
        try ScreenAuditValidator.makeDefault(ocr: ocr).validate(
            screenshotsDirectory: fixture.screenshots,
            contractFile: fixture.contractFile,
            outputDirectory: fixture.output,
            baselineDirectory: baselineDirectory
        )
    }

    private func contract(
        project: String,
        screenID: String,
        filename: String,
        width: Int,
        height: Int,
        required: [String] = [],
        forbidden: [String] = []
    ) -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "\(project)",
          "screens": [
            {
              "id": "\(screenID)",
              "filename": "\(filename)",
              "devices": [{ "label": "fixture", "pixelWidth": \(width), "pixelHeight": \(height) }],
              "text": { "required": \(jsonArray(required)), "optional": [], "forbidden": \(jsonArray(forbidden)) },
              "severityOverrides": {}
            }
          ]
        }
        """
    }

    private func baselineContract() -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "Baseline Walkthrough",
          "screens": [
            {
              "id": "onboarding",
              "filename": "screen.png",
              "devices": [{ "label": "fixture", "pixelWidth": 390, "pixelHeight": 844 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": {
                "protected": [{ "name": "instruction-card", "x": 34, "y": 180, "width": 322, "height": 390 }],
                "ignored": [{ "name": "status-clock", "x": 18, "y": 14, "width": 96, "height": 28 }]
              },
              "baseline": { "referencePath": "screen.png", "maxMismatchRatio": 0.01 },
              "severityOverrides": {}
            }
          ]
        }
        """
    }

    private func tvFocusContract() -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "tvOS Focus Walkthrough",
          "screens": [
            {
              "id": "library",
              "filename": "screen.png",
              "devices": [{ "label": "fixture", "pixelWidth": 960, "pixelHeight": 540 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": { "protected": [{ "name": "focused-tile", "x": 86, "y": 172, "width": 262, "height": 186 }] },
              "baseline": { "referencePath": "screen.png", "maxMismatchRatio": 0.01 },
              "severityOverrides": {}
            }
          ]
        }
        """
    }

    private func macToolbarContract() -> String {
        contract(
            project: "macOS Toolbar Walkthrough",
            screenID: "libraryWindow",
            filename: "screen.png",
            width: 900,
            height: 560,
            required: ["Search", "Share", "Help"]
        )
    }

    private func visualArtifactContract(filename: String) -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "Visual Artifact Walkthrough",
          "screens": [
            \(visualScreenJSON(id: "art", filename: filename))
          ]
        }
        """
    }

    private func visualScreenJSON(id: String, filename: String) -> String {
        """
        {
          "id": "\(id)",
          "filename": "\(filename)",
          "devices": [{ "label": "fixture", "pixelWidth": 390, "pixelHeight": 844 }],
          "text": { "required": [], "optional": [], "forbidden": [] },
          "regions": { "critical": [{ "name": "hero-art", "x": 44, "y": 176, "width": 302, "height": 292 }] },
          "severityOverrides": {}
        }
        """
    }

    private func flowContract() -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "Flow Walkthrough",
          "screens": [
            {
              "id": "welcome",
              "filename": "01_Welcome.png",
              "devices": [{ "label": "fixture", "pixelWidth": 390, "pixelHeight": 844 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            },
            {
              "id": "permissions",
              "filename": "02_Permissions.png",
              "devices": [{ "label": "fixture", "pixelWidth": 390, "pixelHeight": 844 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            },
            {
              "id": "ready",
              "filename": "03_Ready.png",
              "devices": [{ "label": "fixture", "pixelWidth": 390, "pixelHeight": 844 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ],
          "flows": [
            {
              "id": "releaseOnboarding",
              "title": "Release Onboarding",
              "steps": [
                { "screenID": "welcome" },
                { "screenID": "permissions", "requirePreviousStepPresent": true },
                { "screenID": "ready", "requirePreviousStepPresent": true }
              ]
            }
          ]
        }
        """
    }

    private func makeFixture(named name: String) throws -> WalkthroughFixture {
        let root = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("feature-walkthrough")
            .appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }

        let screenshots = root.appendingPathComponent("screenshots")
        let baselines = root.appendingPathComponent("baselines")
        let output = root.appendingPathComponent("reports")
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baselines, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        return WalkthroughFixture(
            root: root,
            screenshots: screenshots,
            baselines: baselines,
            output: output,
            contractFile: root.appendingPathComponent("contracts.json")
        )
    }

    private func drawIOSAlert(includeCancel: Bool, to url: URL) throws {
        try renderBitmap(size: .portraitPhone, to: url) { [self] bounds in
            drawIPhoneChrome(bounds: bounds, title: "Files")
            fill(NSColor.black.withAlphaComponent(0.18), rect: bounds)
            let alert = CGRect(x: 38, y: 280, width: 314, height: includeCancel ? 238 : 190)
            fill(.white, rounded: alert, radius: 22)
            drawText("Delete saved project?", in: CGRect(x: 62, y: 306, width: 266, height: 34), size: 22, weight: .semibold, color: .black, alignment: .center)
            drawText("This action removes the local copy from every device using this account.", in: CGRect(x: 66, y: 348, width: 258, height: 54), size: 15, color: .darkGray, alignment: .center)
            drawDivider(y: 420, x: 38, width: 314)
            drawText("Delete", in: CGRect(x: 38, y: 426, width: 314, height: 48), size: 21, weight: .semibold, color: .systemRed, alignment: .center)
            if includeCancel {
                drawDivider(y: 480, x: 38, width: 314)
                drawText("Cancel", in: CGRect(x: 38, y: 486, width: 314, height: 48), size: 21, weight: .semibold, color: .systemBlue, alignment: .center)
            }
        }
    }

    private func drawSettingsPanel(includesDebugCopy: Bool, to url: URL) throws {
        try renderBitmap(size: .portraitPhone, to: url) { [self] bounds in
            drawIPhoneChrome(bounds: bounds, title: "Privacy")
            drawSettingsRow(y: 142, icon: "mic.fill", title: "Microphone", detail: "Allowed")
            drawSettingsRow(y: 214, icon: "location.fill", title: "Location", detail: "While Using")
            drawSettingsRow(y: 286, icon: "bell.fill", title: "Notifications", detail: "On")
            if includesDebugCopy {
                fill(NSColor.systemYellow.withAlphaComponent(0.26), rounded: CGRect(x: 28, y: 380, width: 334, height: 92), radius: 14)
                drawText("DEBUG BUILD", in: CGRect(x: 48, y: 398, width: 294, height: 26), size: 24, weight: .bold, color: .systemRed)
                drawText("TODO: wire API before release", in: CGRect(x: 48, y: 432, width: 294, height: 24), size: 16, color: .darkGray)
            } else {
                fill(NSColor.controlBackgroundColor, rounded: CGRect(x: 28, y: 380, width: 334, height: 92), radius: 14)
                drawText("Privacy Review", in: CGRect(x: 48, y: 404, width: 294, height: 26), size: 21, weight: .semibold, color: .black)
                drawText("All required permissions are configured.", in: CGRect(x: 48, y: 436, width: 294, height: 24), size: 16, color: .darkGray)
            }
        }
    }

    private func drawIPhoneCommerceScreen(size: CGSize, clippedMenu: Bool, to url: URL) throws {
        try renderBitmap(size: size, to: url) { [self] bounds in
            drawIPhoneChrome(bounds: bounds, title: "Checkout")
            fill(NSColor.controlBackgroundColor, rounded: CGRect(x: 24, y: 132, width: min(bounds.width - 48, 342), height: 162), radius: 18)
            drawText("Order Summary", in: CGRect(x: 44, y: 154, width: 250, height: 30), size: 24, weight: .bold, color: .black)
            drawText("Express shipping arrives tomorrow.", in: CGRect(x: 44, y: 196, width: 290, height: 26), size: 17, color: .darkGray)
            fill(.systemBlue, rounded: CGRect(x: 44, y: 240, width: 240, height: 44), radius: 12)
            drawText("Continue", in: CGRect(x: 44, y: 250, width: 240, height: 24), size: 20, weight: .semibold, color: .white, alignment: .center)
            let tabY = clippedMenu ? bounds.height - 38 : bounds.height - 96
            fill(.white, rect: CGRect(x: 0, y: tabY, width: bounds.width, height: 96))
            drawText("Home", in: CGRect(x: 20, y: tabY + 20, width: 70, height: 24), size: 16, color: .darkGray, alignment: .center)
            drawText("Cart", in: CGRect(x: bounds.width / 2 - 35, y: tabY + 20, width: 70, height: 24), size: 16, color: .systemBlue, alignment: .center)
            drawText("Menu", in: CGRect(x: bounds.width - 90, y: tabY + 20, width: 70, height: 24), size: 16, color: .darkGray, alignment: .center)
        }
    }

    private func drawOnboardingCard(clippedCTA: Bool, clockVariant: Bool, to url: URL) throws {
        try renderBitmap(size: .portraitPhone, to: url) { [self] bounds in
            drawIPhoneChrome(bounds: bounds, title: "Onboarding", clock: clockVariant ? "10:42" : "10:41")
            fill(.white, rounded: CGRect(x: 34, y: 180, width: 322, height: 390), radius: 24)
            drawText("Stay in control", in: CGRect(x: 58, y: 220, width: 274, height: 34), size: 27, weight: .bold, color: .black, alignment: .center)
            drawText("Review permissions before your first recording begins.", in: CGRect(x: 62, y: 274, width: 266, height: 62), size: 18, color: .darkGray, alignment: .center)
            let button = clippedCTA ? CGRect(x: 58, y: 542, width: 274, height: 54) : CGRect(x: 58, y: 476, width: 274, height: 54)
            fill(.systemBlue, rounded: button, radius: 16)
            drawText("Continue", in: button.insetBy(dx: 0, dy: 13), size: 22, weight: .semibold, color: .white, alignment: .center)
            if clippedCTA {
                fill(NSColor.windowBackgroundColor, rect: CGRect(x: 34, y: 570, width: 322, height: 90))
            }
        }
    }

    private func drawTVFocusScreen(hasFocusRing: Bool, to url: URL) throws {
        try renderBitmap(size: .tvLandscape, background: NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1), to: url) { [self] _ in
            drawText("Continue Watching", in: CGRect(x: 76, y: 54, width: 520, height: 44), size: 36, weight: .bold, color: .white)
            drawTVTile(x: 86, y: 172, title: "Quest Basics", focused: hasFocusRing)
            drawTVTile(x: 374, y: 172, title: "Practice", focused: false)
            drawTVTile(x: 662, y: 172, title: "Results", focused: false)
        }
    }

    private func drawMacWindowToolbar(includeHelp: Bool, to url: URL) throws {
        try renderBitmap(size: .macWindow, background: .clear, to: url) { [self] _ in
            let window = CGRect(x: 50, y: 58, width: 800, height: 444)
            fill(.white, rounded: window, radius: 16)
            fill(NSColor(calibratedWhite: 0.93, alpha: 1), rounded: CGRect(x: 50, y: 58, width: 800, height: 72), radius: 16)
            drawTrafficLights(origin: CGPoint(x: 78, y: 88))
            drawToolbarButton("Search", x: 498)
            drawToolbarButton("Share", x: 606)
            if includeHelp {
                drawToolbarButton("Help", x: 706)
            }
            drawText("Project Library", in: CGRect(x: 84, y: 162, width: 420, height: 38), size: 30, weight: .bold, color: .black)
            fill(NSColor.controlBackgroundColor, rounded: CGRect(x: 84, y: 224, width: 732, height: 190), radius: 16)
        }
    }

    private func drawArtworkCard(style: ArtworkStyle, to url: URL) throws {
        try renderBitmap(size: .portraitPhone, to: url) { [self] bounds in
            drawIPhoneChrome(bounds: bounds, title: "Today")
            fill(.white, rounded: CGRect(x: 28, y: 132, width: 334, height: 506), radius: 26)
            let art = CGRect(x: 44, y: 176, width: 302, height: 292)
            switch style {
            case .healthyArt:
                drawHealthyArt(in: art)
            case .flatMatte:
                fill(NSColor(calibratedWhite: 0.62, alpha: 1), rounded: art, radius: 18)
            case .checkerboard:
                drawCheckerboard(in: art)
            }
            drawText("Daily Quest", in: CGRect(x: 52, y: 498, width: 286, height: 32), size: 26, weight: .bold, color: .black)
            drawText("Artwork should render cleanly here.", in: CGRect(x: 52, y: 538, width: 286, height: 26), size: 17, color: .darkGray)
        }
    }

    private func drawFlowStep(title: String, subtitle: String, to url: URL) throws {
        try renderBitmap(size: .portraitPhone, to: url) { [self] bounds in
            drawIPhoneChrome(bounds: bounds, title: "Setup")
            fill(.white, rounded: CGRect(x: 34, y: 190, width: 322, height: 360), radius: 28)
            fill(.systemBlue, rounded: CGRect(x: 134, y: 236, width: 122, height: 122), radius: 32)
            drawText(title, in: CGRect(x: 56, y: 392, width: 278, height: 42), size: 33, weight: .bold, color: .black, alignment: .center)
            drawText(subtitle, in: CGRect(x: 62, y: 446, width: 266, height: 34), size: 20, color: .darkGray, alignment: .center)
            fill(.systemBlue, rounded: CGRect(x: 78, y: 502, width: 234, height: 50), radius: 16)
            drawText("Continue", in: CGRect(x: 78, y: 515, width: 234, height: 24), size: 21, weight: .semibold, color: .white, alignment: .center)
        }
    }

    private func writeOpaqueBorderAsset(to url: URL) throws {
        var pixels: [WalkthroughPixel] = []
        let width = 390
        let height = 844
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let onImageEdge = x < 18 || x >= width - 18 || y < 18 || y >= height - 18
                pixels.append(onImageEdge ? .black : .transparent)
            }
        }
        try writePNG(width: width, height: height, pixels: pixels, to: url)
    }

    private func renderBitmap(
        size: CGSize,
        background: NSColor = NSColor.windowBackgroundColor,
        to url: URL,
        draw: @escaping (CGRect) -> Void
    ) throws {
        let image = NSImage(size: size, flipped: true) { bounds in
            background.setFill()
            bounds.fill()
            draw(bounds)
            return true
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            struct EncodeError: Error {}
            throw EncodeError()
        }

        try png.write(to: url, options: .atomic)
    }

    private func writePNG(width: Int, height: Int, pixels: [WalkthroughPixel], to url: URL) throws {
        XCTAssertEqual(pixels.count, width * height)
        var bytes = pixels.flatMap(\.rgba)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(
            CGContext(
                data: &bytes,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func drawIPhoneChrome(bounds: CGRect, title: String, clock: String = "10:41") {
        drawText(clock, in: CGRect(x: 20, y: 16, width: 86, height: 22), size: 17, weight: .semibold, color: .black)
        drawText(title, in: CGRect(x: 84, y: 74, width: bounds.width - 168, height: 32), size: 23, weight: .bold, color: .black, alignment: .center)
    }

    private func drawSettingsRow(y: CGFloat, icon: String, title: String, detail: String) {
        fill(.white, rounded: CGRect(x: 28, y: y, width: 334, height: 58), radius: 14)
        fill(.systemBlue, rounded: CGRect(x: 42, y: y + 13, width: 32, height: 32), radius: 8)
        drawText(title, in: CGRect(x: 88, y: y + 16, width: 160, height: 24), size: 18, weight: .semibold, color: .black)
        drawText(detail, in: CGRect(x: 242, y: y + 17, width: 96, height: 22), size: 15, color: .darkGray, alignment: .right)
    }

    private func drawTVTile(x: CGFloat, y: CGFloat, title: String, focused: Bool) {
        let tile = CGRect(x: x, y: y, width: 236, height: 154)
        if focused {
            fill(.systemBlue, rounded: tile.insetBy(dx: -10, dy: -10), radius: 26)
        }
        fill(NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.22, alpha: 1), rounded: tile, radius: 20)
        drawText(title, in: CGRect(x: x, y: y + 172, width: 236, height: 28), size: 24, weight: .semibold, color: .white, alignment: .center)
    }

    private func drawTrafficLights(origin: CGPoint) {
        for (index, color) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: CGRect(x: origin.x + CGFloat(index * 22), y: origin.y, width: 13, height: 13)).fill()
        }
    }

    private func drawToolbarButton(_ title: String, x: CGFloat) {
        fill(.white, rounded: CGRect(x: x, y: 76, width: 86, height: 34), radius: 9)
        drawText(title, in: CGRect(x: x, y: 83, width: 86, height: 20), size: 15, weight: .semibold, color: .black, alignment: .center)
    }

    private func drawHealthyArt(in rect: CGRect) {
        fill(NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.48, alpha: 1), rounded: rect, radius: 18)
        fill(NSColor(calibratedRed: 0.98, green: 0.56, blue: 0.20, alpha: 1), rounded: rect.insetBy(dx: 44, dy: 54), radius: 32)
        fill(NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.68, alpha: 1), rounded: CGRect(x: rect.minX + 168, y: rect.minY + 64, width: 88, height: 126), radius: 24)
        fill(NSColor.white.withAlphaComponent(0.86), rounded: CGRect(x: rect.minX + 70, y: rect.minY + 196, width: 168, height: 18), radius: 9)
    }

    private func drawCheckerboard(in rect: CGRect) {
        let cell: CGFloat = 8
        var y = rect.minY
        var row = 0
        while y < rect.maxY {
            var x = rect.minX
            var column = 0
            while x < rect.maxX {
                let color = (row + column).isMultiple(of: 2) ? NSColor(calibratedWhite: 0.82, alpha: 1) : NSColor(calibratedWhite: 0.58, alpha: 1)
                fill(color, rect: CGRect(x: x, y: y, width: cell, height: cell))
                x += cell
                column += 1
            }
            y += cell
            row += 1
        }
    }

    private func fill(_ color: NSColor, rect: CGRect) {
        color.setFill()
        rect.fill()
    }

    private func fill(_ color: NSColor, rounded rect: CGRect, radius: CGFloat) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    private func drawDivider(y: CGFloat, x: CGFloat, width: CGFloat) {
        fill(NSColor.separatorColor, rect: CGRect(x: x, y: y, width: width, height: 1))
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private func jsonArray(_ values: [String]) -> String {
        let escaped = values.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }
        return "[\(escaped.joined(separator: ", "))]"
    }

    private func summaryText(for fixture: WalkthroughFixture) throws -> String {
        try String(contentsOf: fixture.output.appendingPathComponent("summary.md"), encoding: .utf8)
    }

    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct WalkthroughFixture {
    let root: URL
    let screenshots: URL
    let baselines: URL
    let output: URL
    let contractFile: URL
}

private enum ArtworkStyle {
    case healthyArt
    case flatMatte
    case checkerboard
}

private enum WalkthroughPixel {
    case black
    case transparent

    var rgba: [UInt8] {
        switch self {
        case .black:
            [0, 0, 0, 255]
        case .transparent:
            [0, 0, 0, 0]
        }
    }
}

private extension CGSize {
    static let portraitPhone = CGSize(width: 390, height: 844)
    static let landscapePhone = CGSize(width: 844, height: 390)
    static let tvLandscape = CGSize(width: 960, height: 540)
    static let macWindow = CGSize(width: 900, height: 560)
}
