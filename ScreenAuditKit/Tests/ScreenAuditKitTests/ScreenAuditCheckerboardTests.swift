import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Tests checkerboard-like visual artifact detection.
final class ScreenAuditCheckerboardTests: XCTestCase {
    /// Verifies alternating cells are flagged as a checkerboard risk.
    func testAlternatingCellsAreCheckerboardRisk() throws {
        let url = try writeFixturePNG(
            named: "checkerboard",
            width: 4,
            height: 4,
            pixels: checkerboardPixels(width: 4, height: 4)
        )

        let inspection = try ScreenAuditCheckerboardInspector().inspect(
            screenshotURL: url,
            region: ScreenAuditRegion(name: "transparent-art", x: 0, y: 0, width: 4, height: 4),
            cellSize: 1
        )

        XCTAssertEqual(inspection.inspectedCellCount, 16)
        XCTAssertEqual(inspection.checkedBlockCount, 9)
        XCTAssertEqual(inspection.alternatingBlockCount, 9)
        XCTAssertEqual(inspection.alternatingRatio, 1.0)
        XCTAssertTrue(inspection.isRisk)
    }

    /// Verifies a uniform region is not flagged as checkerboard risk.
    func testUniformRegionIsNotCheckerboardRisk() throws {
        let url = try writeFixturePNG(
            named: "uniform",
            width: 4,
            height: 4,
            pixels: Array(repeating: .blue, count: 16)
        )

        let inspection = try ScreenAuditCheckerboardInspector().inspect(
            screenshotURL: url,
            region: ScreenAuditRegion(name: "art", x: 0, y: 0, width: 4, height: 4),
            cellSize: 1
        )

        XCTAssertEqual(inspection.checkedBlockCount, 9)
        XCTAssertEqual(inspection.alternatingBlockCount, 0)
        XCTAssertEqual(inspection.alternatingRatio, 0)
        XCTAssertFalse(inspection.isRisk)
    }

    /// Verifies regions too small for neighboring cells are not flagged.
    func testSmallRegionIsNotCheckerboardRisk() throws {
        let url = try writeFixturePNG(
            named: "small",
            width: 1,
            height: 1,
            pixels: [.lightGray]
        )

        let inspection = try ScreenAuditCheckerboardInspector().inspect(
            screenshotURL: url,
            region: ScreenAuditRegion(name: "tiny", x: 0, y: 0, width: 1, height: 1),
            cellSize: 1
        )

        XCTAssertEqual(inspection.inspectedCellCount, 1)
        XCTAssertEqual(inspection.checkedBlockCount, 0)
        XCTAssertFalse(inspection.isRisk)
    }

    /// Verifies checkerboard inspections can be converted into findings.
    func testCheckerboardRiskInspectionCreatesFinding() throws {
        let region = ScreenAuditRegion(name: "critical-art", x: 0, y: 0, width: 4, height: 4)
        let inspection = ScreenAuditCheckerboardInspection(
            region: region,
            cellSize: 1,
            inspectedCellCount: 16,
            checkedBlockCount: 9,
            alternatingBlockCount: 9,
            alternatingRatio: 1.0,
            isRisk: true
        )

        let finding = try XCTUnwrap(
            ScreenAuditCheckerboardInspector().findingIfNeeded(
                inspection: inspection,
                screenID: "screen",
                path: "screen.png"
            )
        )

        XCTAssertEqual(finding.ruleID, .checkerboardPatternRisk)
        XCTAssertEqual(finding.severity, .warning)
        XCTAssertEqual(finding.confidence, 0.75)
        XCTAssertTrue(finding.message.contains("critical-art"))
    }

    private func checkerboardPixels(width: Int, height: Int) -> [CheckerboardFixturePixel] {
        var pixels: [CheckerboardFixturePixel] = []
        pixels.reserveCapacity(width * height)

        for y in 0..<height {
            for x in 0..<width {
                pixels.append((x + y).isMultiple(of: 2) ? .lightGray : .darkGray)
            }
        }

        return pixels
    }

    private func writeFixturePNG(
        named name: String,
        width: Int,
        height: Int,
        pixels: [CheckerboardFixturePixel]
    ) throws -> URL {
        XCTAssertEqual(pixels.count, width * height)
        let directory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("checkerboard")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")

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
        return url
    }

    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private enum CheckerboardFixturePixel {
    case lightGray
    case darkGray
    case blue

    var rgba: [UInt8] {
        switch self {
        case .lightGray:
            [210, 210, 210, 255]
        case .darkGray:
            [150, 150, 150, 255]
        case .blue:
            [0, 80, 255, 255]
        }
    }
}
