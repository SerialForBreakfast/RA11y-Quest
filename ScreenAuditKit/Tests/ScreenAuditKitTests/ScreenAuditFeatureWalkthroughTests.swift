import AppKit
import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Stakeholder-grade proof tests that run ScreenAuditKit against generated PNG screenshots.
final class ScreenAuditFeatureWalkthroughTests: XCTestCase {
    /// Proves text gates distinguish missing copy, forbidden copy, and intentional no-OCR skips.
    func testTextWalkthroughCatchesMissingAndForbiddenCopyAndSkipsWhenOCROff() throws {
        let missing = try makeFixture(named: "text-missing")
        try writeTextPNG("READY42", to: missing.screenshots.appendingPathComponent("screen.png"))
        try textContract().write(to: missing.contractFile, atomically: true, encoding: .utf8)

        let missingResult = try ScreenAuditValidator.makeDefault(ocr: .vision).validate(
            screenshotsDirectory: missing.screenshots,
            contractFile: missing.contractFile,
            outputDirectory: missing.output
        )

        XCTAssertTrue(missingResult.findingsReport.findings.contains { $0.ruleID == .requiredTextMissing && $0.severity == .error })
        XCTAssertTrue(try summaryText(for: missing).contains("requiredTextMissing"))

        let forbidden = try makeFixture(named: "text-forbidden")
        try writeTextPNG("OCRFIX42 DEBUG42", to: forbidden.screenshots.appendingPathComponent("screen.png"))
        try textContract().write(to: forbidden.contractFile, atomically: true, encoding: .utf8)

        let forbiddenResult = try ScreenAuditValidator.makeDefault(ocr: .vision).validate(
            screenshotsDirectory: forbidden.screenshots,
            contractFile: forbidden.contractFile,
            outputDirectory: forbidden.output
        )

        XCTAssertTrue(forbiddenResult.findingsReport.findings.contains { $0.ruleID == .forbiddenTextPresent && $0.severity == .error })
        XCTAssertTrue(try summaryText(for: forbidden).contains("forbiddenTextPresent"))

        let noOCR = try makeFixture(named: "text-no-ocr")
        try writeTextPNG("OCRFIX42", to: noOCR.screenshots.appendingPathComponent("screen.png"))
        try textContract().write(to: noOCR.contractFile, atomically: true, encoding: .utf8)

        let noOCRResult = try ScreenAuditValidator.makeDefault(ocr: .none).validate(
            screenshotsDirectory: noOCR.screenshots,
            contractFile: noOCR.contractFile,
            outputDirectory: noOCR.output
        )

        XCTAssertFalse(noOCRResult.findingsReport.hasHardFailures)
        XCTAssertTrue(noOCRResult.findingsReport.findings.contains { $0.ruleID == .textRulesSkipped && $0.severity == .info })
    }

    /// Proves exact device dimensions catch screenshots from the wrong capture profile.
    func testDimensionWalkthroughCatchesWrongDeviceSize() throws {
        let fixture = try makeFixture(named: "dimension-mismatch")
        try writeSolidPNG(width: 321, height: 180, color: .blue, to: fixture.screenshots.appendingPathComponent("screen.png"))
        try """
        {
          "schemaVersion": 1,
          "projectName": "Dimension Walkthrough",
          "screens": [
            {
              "id": "screen",
              "filename": "screen.png",
              "devices": [{ "label": "demo-phone", "pixelWidth": 320, "pixelHeight": 180 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ]
        }
        """.write(to: fixture.contractFile, atomically: true, encoding: .utf8)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: fixture.screenshots,
            contractFile: fixture.contractFile,
            outputDirectory: fixture.output
        )

        XCTAssertTrue(result.findingsReport.findings.contains { $0.ruleID == .dimensionMismatch && $0.severity == .error })
        XCTAssertTrue(try summaryText(for: fixture).contains("321x180"))
    }

    /// Proves baseline comparison ignores volatile regions while flagging meaningful protected drift.
    func testBaselineWalkthroughIgnoresVolatileRegionAndFlagsProtectedDrift() throws {
        let ignoredOnly = try makeFixture(named: "baseline-ignored-only")
        try writeBaselinePNG(changesProtectedRegion: false, to: ignoredOnly.screenshots.appendingPathComponent("screen.png"))
        try writeBaselinePNG(changesProtectedRegion: false, baselineMode: true, to: ignoredOnly.baselines.appendingPathComponent("screen.png"))
        try baselineContract().write(to: ignoredOnly.contractFile, atomically: true, encoding: .utf8)

        let ignoredResult = try ScreenAuditValidator().validate(
            screenshotsDirectory: ignoredOnly.screenshots,
            contractFile: ignoredOnly.contractFile,
            outputDirectory: ignoredOnly.output,
            baselineDirectory: ignoredOnly.baselines
        )

        XCTAssertFalse(ignoredResult.findingsReport.findings.contains { $0.ruleID == .baselineDifferenceExceeded })

        let protectedDrift = try makeFixture(named: "baseline-protected-drift")
        try writeBaselinePNG(changesProtectedRegion: true, to: protectedDrift.screenshots.appendingPathComponent("screen.png"))
        try writeBaselinePNG(changesProtectedRegion: false, baselineMode: true, to: protectedDrift.baselines.appendingPathComponent("screen.png"))
        try baselineContract().write(to: protectedDrift.contractFile, atomically: true, encoding: .utf8)

        let driftResult = try ScreenAuditValidator().validate(
            screenshotsDirectory: protectedDrift.screenshots,
            contractFile: protectedDrift.contractFile,
            outputDirectory: protectedDrift.output,
            baselineDirectory: protectedDrift.baselines
        )

        XCTAssertTrue(driftResult.findingsReport.findings.contains { $0.ruleID == .baselineDifferenceExceeded && $0.severity == .warning })
        XCTAssertFalse(driftResult.overlayPaths.isEmpty)
        XCTAssertTrue(try summaryText(for: protectedDrift).contains("baselineDifferenceExceeded"))
    }

    /// Proves high-signal visual artifact rules catch checkerboards, flat mattes, and alpha-border defects.
    func testVisualArtifactWalkthroughProducesFindingsAndOverlays() throws {
        let fixture = try makeFixture(named: "visual-artifacts")
        try writeCheckerboardPNG(width: 64, height: 64, to: fixture.screenshots.appendingPathComponent("checker.png"))
        try writeSolidPNG(width: 64, height: 64, color: .midGray, to: fixture.screenshots.appendingPathComponent("matte.png"))
        try writeOpaqueBorderPNG(width: 16, height: 16, to: fixture.screenshots.appendingPathComponent("alpha.png"))
        try """
        {
          "schemaVersion": 1,
          "projectName": "Visual Artifact Walkthrough",
          "screens": [
            {
              "id": "checker",
              "filename": "checker.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": { "critical": [{ "name": "critical-art", "x": 0, "y": 0, "width": 64, "height": 64 }] },
              "severityOverrides": {}
            },
            {
              "id": "matte",
              "filename": "matte.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": { "critical": [{ "name": "critical-art", "x": 0, "y": 0, "width": 64, "height": 64 }] },
              "severityOverrides": {}
            },
            {
              "id": "alpha",
              "filename": "alpha.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ]
        }
        """.write(to: fixture.contractFile, atomically: true, encoding: .utf8)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: fixture.screenshots,
            contractFile: fixture.contractFile,
            outputDirectory: fixture.output
        )

        let ruleIDs = Set(result.findingsReport.findings.map(\.ruleID))
        XCTAssertTrue(ruleIDs.contains(.checkerboardPatternRisk))
        XCTAssertTrue(ruleIDs.contains(.renderedMatteRisk))
        XCTAssertTrue(ruleIDs.contains(.suspiciousOpaqueBorder))
        XCTAssertEqual(result.overlayPaths.count, 3)
        XCTAssertTrue(try summaryText(for: fixture).contains("checkerboardPatternRisk"))
        XCTAssertTrue(try summaryText(for: fixture).contains("suspiciousOpaqueBorder"))
    }

    /// Proves ordered journey validation catches a later screen appearing without its required predecessor.
    func testFlowWalkthroughCatchesMissingRequiredPredecessor() throws {
        let fixture = try makeFixture(named: "flow-missing-predecessor")
        try writeSolidPNG(width: 40, height: 40, color: .green, to: fixture.screenshots.appendingPathComponent("02_Result.png"))
        try """
        {
          "schemaVersion": 1,
          "projectName": "Flow Walkthrough",
          "screens": [
            {
              "id": "intro",
              "filename": "01_Intro.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            },
            {
              "id": "result",
              "filename": "02_Result.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ],
          "flows": [
            {
              "id": "releaseJourney",
              "title": "Release Journey",
              "steps": [
                { "screenID": "intro" },
                { "screenID": "result", "requirePreviousStepPresent": true }
              ]
            }
          ]
        }
        """.write(to: fixture.contractFile, atomically: true, encoding: .utf8)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: fixture.screenshots,
            contractFile: fixture.contractFile,
            outputDirectory: fixture.output
        )

        let ruleIDs = Set(result.findingsReport.findings.map(\.ruleID))
        XCTAssertTrue(ruleIDs.contains(.missingScreenshot))
        XCTAssertTrue(ruleIDs.contains(.flowMissingRequiredStep))
        XCTAssertTrue(ruleIDs.contains(.flowPreviousStepMissing))
        XCTAssertTrue(try String(contentsOf: fixture.output.appendingPathComponent("flow-summary.md"), encoding: .utf8).contains("| 1 | intro | yes | missing |"))
    }

    /// Proves a complete generated screenshot journey produces reports without findings.
    func testCleanHappyPathWalkthroughProducesNoFindings() throws {
        let fixture = try makeFixture(named: "clean-happy-path")
        try writeSolidPNG(width: 40, height: 40, color: .blue, to: fixture.screenshots.appendingPathComponent("01_Start.png"))
        try writeSolidPNG(width: 40, height: 40, color: .green, to: fixture.screenshots.appendingPathComponent("02_Result.png"))
        try """
        {
          "schemaVersion": 1,
          "projectName": "Clean Walkthrough",
          "screens": [
            {
              "id": "start",
              "filename": "01_Start.png",
              "devices": [{ "label": "fixture", "pixelWidth": 40, "pixelHeight": 40 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            },
            {
              "id": "result",
              "filename": "02_Result.png",
              "devices": [{ "label": "fixture", "pixelWidth": 40, "pixelHeight": 40 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ],
          "flows": [
            {
              "id": "cleanJourney",
              "title": "Clean Journey",
              "steps": [
                { "screenID": "start" },
                { "screenID": "result", "requirePreviousStepPresent": true }
              ]
            }
          ]
        }
        """.write(to: fixture.contractFile, atomically: true, encoding: .utf8)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: fixture.screenshots,
            contractFile: fixture.contractFile,
            outputDirectory: fixture.output
        )

        XCTAssertTrue(result.findingsReport.findings.isEmpty)
        XCTAssertTrue(try summaryText(for: fixture).contains("No findings."))
        XCTAssertTrue(try String(contentsOf: fixture.output.appendingPathComponent("flow-summary.md"), encoding: .utf8).contains("Clean Journey"))
    }

    private func textContract() -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "Text Walkthrough",
          "screens": [
            {
              "id": "screen",
              "filename": "screen.png",
              "devices": [{ "label": "fixture", "pixelWidth": 800, "pixelHeight": 220 }],
              "text": { "required": ["OCRFIX42"], "optional": [], "forbidden": ["DEBUG42"] },
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
              "id": "screen",
              "filename": "screen.png",
              "devices": [{ "label": "fixture", "pixelWidth": 20, "pixelHeight": 10 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": {
                "protected": [{ "name": "stable-content", "x": 10, "y": 0, "width": 10, "height": 10 }],
                "ignored": [{ "name": "clock", "x": 0, "y": 0, "width": 10, "height": 10 }]
              },
              "baseline": { "referencePath": "screen.png", "maxMismatchRatio": 0.01 },
              "severityOverrides": {}
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

    private func writeTextPNG(_ text: String, to url: URL) throws {
        let size = NSSize(width: 800, height: 220)
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor.white.setFill()
            bounds.fill()
            let font = NSFont.monospacedSystemFont(ofSize: 72, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
                .kern: 4,
            ]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            attributed.draw(at: NSPoint(x: 48, y: (bounds.height - attributed.size().height) / 2))
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

    private func writeBaselinePNG(
        changesProtectedRegion: Bool,
        baselineMode: Bool = false,
        to url: URL
    ) throws {
        var pixels: [WalkthroughPixel] = []
        pixels.reserveCapacity(20 * 10)
        for y in 0..<10 {
            for x in 0..<20 {
                if x < 10 {
                    pixels.append(baselineMode ? .red : .green)
                } else if changesProtectedRegion && y < 5 {
                    pixels.append(.blue)
                } else {
                    pixels.append(.red)
                }
            }
        }
        try writePNG(width: 20, height: 10, pixels: pixels, to: url)
    }

    private func writeSolidPNG(width: Int, height: Int, color: WalkthroughPixel, to url: URL) throws {
        try writePNG(width: width, height: height, pixels: Array(repeating: color, count: width * height), to: url)
    }

    private func writeCheckerboardPNG(width: Int, height: Int, to url: URL) throws {
        var pixels: [WalkthroughPixel] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels.append((x / 8 + y / 8).isMultiple(of: 2) ? .red : .blue)
            }
        }
        try writePNG(width: width, height: height, pixels: pixels, to: url)
    }

    private func writeOpaqueBorderPNG(width: Int, height: Int, to url: URL) throws {
        var pixels: [WalkthroughPixel] = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let isEdge = x == 0 || y == 0 || x == width - 1 || y == height - 1
                pixels.append(isEdge ? .black : .transparent)
            }
        }
        try writePNG(width: width, height: height, pixels: pixels, to: url)
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

private enum WalkthroughPixel {
    case red
    case green
    case blue
    case midGray
    case black
    case transparent

    var rgba: [UInt8] {
        switch self {
        case .red:
            [220, 40, 45, 255]
        case .green:
            [40, 170, 90, 255]
        case .blue:
            [45, 80, 220, 255]
        case .midGray:
            [160, 160, 160, 255]
        case .black:
            [0, 0, 0, 255]
        case .transparent:
            [0, 0, 0, 0]
        }
    }
}
