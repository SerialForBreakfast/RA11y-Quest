import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Tests rendered screenshot matte-risk heuristics.
final class ScreenAuditRenderedMatteTests: XCTestCase {
    /// Verifies a critical region dominated by flat gray pixels is flagged.
    func testFlatGrayCriticalRegionIsMatteRisk() throws {
        let url = try writeFixturePNG(
            named: "flat-gray",
            width: 4,
            height: 4,
            pixels: Array(repeating: .midGray, count: 16)
        )

        let inspection = try ScreenAuditRenderedMatteInspector().inspect(
            screenshotURL: url,
            region: ScreenAuditRegion(name: "sprite-frame", x: 0, y: 0, width: 4, height: 4)
        )

        XCTAssertEqual(inspection.inspectedPixels, 16)
        XCTAssertEqual(inspection.matteLikePixels, 16)
        XCTAssertEqual(inspection.matteLikeRatio, 1.0)
        XCTAssertTrue(inspection.isRisk)
    }

    /// Verifies colorful regions are not flagged as matte blocks.
    func testColorfulCriticalRegionIsNotMatteRisk() throws {
        let url = try writeFixturePNG(
            named: "colorful",
            width: 4,
            height: 4,
            pixels: Array(repeating: .blue, count: 16)
        )

        let inspection = try ScreenAuditRenderedMatteInspector().inspect(
            screenshotURL: url,
            region: ScreenAuditRegion(name: "art", x: 0, y: 0, width: 4, height: 4)
        )

        XCTAssertEqual(inspection.inspectedPixels, 16)
        XCTAssertEqual(inspection.matteLikePixels, 0)
        XCTAssertEqual(inspection.matteLikeRatio, 0)
        XCTAssertFalse(inspection.isRisk)
    }

    /// Verifies regions are clamped to image bounds before analysis.
    func testRegionOutsideBoundsIsClamped() throws {
        let url = try writeFixturePNG(
            named: "clamped",
            width: 4,
            height: 4,
            pixels: Array(repeating: .white, count: 16)
        )

        let inspection = try ScreenAuditRenderedMatteInspector().inspect(
            screenshotURL: url,
            region: ScreenAuditRegion(name: "oversized", x: 2, y: 2, width: 10, height: 10)
        )

        XCTAssertEqual(inspection.region.x, 2)
        XCTAssertEqual(inspection.region.y, 2)
        XCTAssertEqual(inspection.region.width, 2)
        XCTAssertEqual(inspection.region.height, 2)
        XCTAssertEqual(inspection.inspectedPixels, 4)
        XCTAssertTrue(inspection.isRisk)
    }

    /// Verifies matte-risk inspections can be converted into findings.
    func testMatteRiskInspectionCreatesFinding() throws {
        let region = ScreenAuditRegion(name: "critical-art", x: 0, y: 0, width: 2, height: 2)
        let inspection = ScreenAuditRenderedMatteInspection(
            region: region,
            inspectedPixels: 4,
            matteLikePixels: 4,
            matteLikeRatio: 1.0,
            isRisk: true
        )

        let finding = try XCTUnwrap(
            ScreenAuditRenderedMatteInspector().findingIfNeeded(
                inspection: inspection,
                screenID: "screen",
                path: "screen.png"
            )
        )

        XCTAssertEqual(finding.ruleID, .renderedMatteRisk)
        XCTAssertEqual(finding.severity, .warning)
        XCTAssertEqual(finding.confidence, 0.7)
        XCTAssertTrue(finding.message.contains("critical-art"))
    }

    /// Verifies region contracts can decode critical regions.
    func testRegionSetDecodesCriticalRegions() throws {
        let json = """
        {
          "protected": [],
          "ignored": [],
          "critical": [
            { "name": "art", "x": 1, "y": 2, "width": 3, "height": 4 }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let regions = try JSONDecoder().decode(ScreenAuditRegionSet.self, from: data)

        XCTAssertEqual(regions.critical, [
            ScreenAuditRegion(name: "art", x: 1, y: 2, width: 3, height: 4)
        ])
    }

    private func writeFixturePNG(
        named name: String,
        width: Int,
        height: Int,
        pixels: [MatteFixturePixel]
    ) throws -> URL {
        XCTAssertEqual(pixels.count, width * height)
        let directory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("rendered-matte")
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

private enum MatteFixturePixel {
    case midGray
    case white
    case blue

    var rgba: [UInt8] {
        switch self {
        case .midGray:
            [160, 160, 160, 255]
        case .white:
            [255, 255, 255, 255]
        case .blue:
            [0, 80, 255, 255]
        }
    }
}
