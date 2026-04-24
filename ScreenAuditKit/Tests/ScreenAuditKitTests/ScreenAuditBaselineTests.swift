import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Tests deterministic baseline image comparison.
final class ScreenAuditBaselineTests: XCTestCase {
    /// Verifies identical images produce a zero mismatch ratio.
    func testIdenticalImagesHaveZeroMismatchRatio() throws {
        let directory = try makeFixtureDirectory(named: "identical")
        let screenshotURL = directory.appendingPathComponent("screenshot.png")
        let baselineURL = directory.appendingPathComponent("baseline.png")
        try writePNG(width: 2, height: 2, pixels: [.red, .red, .red, .red], to: screenshotURL)
        try writePNG(width: 2, height: 2, pixels: [.red, .red, .red, .red], to: baselineURL)

        let diff = try ScreenAuditBaselineComparator().compare(
            screenshotURL: screenshotURL,
            baselineURL: baselineURL,
            ignoredRegions: []
        )

        XCTAssertEqual(diff.comparedPixels, 4)
        XCTAssertEqual(diff.mismatchedPixels, 0)
        XCTAssertEqual(diff.mismatchRatio, 0)
    }

    /// Verifies mismatched pixels are counted after ignored regions are removed.
    func testIgnoredRegionsAreSkippedDuringComparison() throws {
        let directory = try makeFixtureDirectory(named: "ignored")
        let screenshotURL = directory.appendingPathComponent("screenshot.png")
        let baselineURL = directory.appendingPathComponent("baseline.png")
        try writePNG(width: 2, height: 2, pixels: [.blue, .red, .red, .red], to: screenshotURL)
        try writePNG(width: 2, height: 2, pixels: [.green, .red, .red, .red], to: baselineURL)

        let diff = try ScreenAuditBaselineComparator().compare(
            screenshotURL: screenshotURL,
            baselineURL: baselineURL,
            ignoredRegions: [
                ScreenAuditRegion(name: "volatile", x: 0, y: 0, width: 1, height: 1)
            ]
        )

        XCTAssertEqual(diff.comparedPixels, 3)
        XCTAssertEqual(diff.mismatchedPixels, 0)
        XCTAssertEqual(diff.mismatchRatio, 0)
    }

    /// Verifies exceeded thresholds produce warning findings by default.
    func testExceededBaselineThresholdProducesFinding() throws {
        let contract = ScreenAuditScreenContract(
            id: "screen",
            filename: "screen.png",
            baseline: ScreenAuditBaselineExpectation(referencePath: "screen.png", maxMismatchRatio: 0.1)
        )
        let evidence = ScreenAuditScreenshotEvidence(
            screenID: "screen",
            path: "screen.png",
            pixelWidth: 2,
            pixelHeight: 2,
            hasAlpha: true
        )
        let diff = ScreenAuditBaselineDiff(comparedPixels: 4, mismatchedPixels: 1, mismatchRatio: 0.25)

        let finding = try XCTUnwrap(
            ScreenAuditBaselineComparator().findingIfNeeded(
                diff: diff,
                contract: contract,
                evidence: evidence
            )
        )

        XCTAssertEqual(finding.ruleID, .baselineDifferenceExceeded)
        XCTAssertEqual(finding.severity, .warning)
        XCTAssertEqual(finding.evidence.excerpt, "1/4 pixels")
    }

    /// Verifies validation can run baseline comparison from filesystem inputs.
    func testValidatorUsesBaselineDirectoryWhenProvided() throws {
        let directory = try makeFixtureDirectory(named: "validator")
        let screenshotsDirectory = directory.appendingPathComponent("screenshots")
        let baselinesDirectory = directory.appendingPathComponent("baselines")
        let outputDirectory = directory.appendingPathComponent("reports")
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baselinesDirectory, withIntermediateDirectories: true)

        try writePNG(
            width: 2,
            height: 2,
            pixels: [.blue, .red, .red, .red],
            to: screenshotsDirectory.appendingPathComponent("screen.png")
        )
        try writePNG(
            width: 2,
            height: 2,
            pixels: [.green, .red, .red, .red],
            to: baselinesDirectory.appendingPathComponent("screen.png")
        )

        let contractFile = directory.appendingPathComponent("contracts.json")
        try """
        {
          "schemaVersion": 1,
          "projectName": "Baseline Fixture",
          "screens": [
            {
              "id": "screen",
              "filename": "screen.png",
              "devices": [],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": {
                "protected": [],
                "ignored": []
              },
              "baseline": {
                "referencePath": "screen.png",
                "maxMismatchRatio": 0.1
              },
              "severityOverrides": {}
            }
          ]
        }
        """.write(to: contractFile, atomically: true, encoding: .utf8)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: screenshotsDirectory,
            contractFile: contractFile,
            outputDirectory: outputDirectory,
            baselineDirectory: baselinesDirectory
        )

        XCTAssertEqual(result.findingsReport.findings.count, 1)
        XCTAssertEqual(result.findingsReport.findings.first?.ruleID, .baselineDifferenceExceeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("summary.md").path))
        XCTAssertEqual(result.overlayPaths.count, 1)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: outputDirectory
                    .appendingPathComponent("overlays")
                    .appendingPathComponent("screen-overlay.png")
                    .path
            )
        )
    }

    private func makeFixtureDirectory(named name: String) throws -> URL {
        let directory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("baseline")
            .appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writePNG(width: Int, height: Int, pixels: [FixturePixel], to url: URL) throws {
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

    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private enum FixturePixel {
    case red
    case blue
    case green

    var rgba: [UInt8] {
        switch self {
        case .red:
            [255, 0, 0, 255]
        case .blue:
            [0, 0, 255, 255]
        case .green:
            [0, 255, 0, 255]
        }
    }
}
