import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Tests PNG transparency and opaque-border heuristics.
final class ScreenAuditTransparencyTests: XCTestCase {
    /// Verifies an opaque border around transparent interior pixels is flagged.
    func testOpaqueBorderAroundTransparentInteriorIsSuspicious() throws {
        let url = try writeFixturePNG(
            named: "opaque-border",
            width: 3,
            height: 3,
            pixels: [
                .opaqueRed, .opaqueRed, .opaqueRed,
                .opaqueRed, .transparent, .opaqueRed,
                .opaqueRed, .opaqueRed, .opaqueRed
            ]
        )

        let inspection = try ScreenAuditTransparencyInspector().inspectOpaqueBorder(at: url)

        XCTAssertEqual(inspection.edgePixelCount, 8)
        XCTAssertEqual(inspection.opaqueEdgePixelCount, 8)
        XCTAssertEqual(inspection.transparentInteriorPixelCount, 1)
        XCTAssertEqual(inspection.opaqueEdgeRatio, 1.0)
        XCTAssertTrue(inspection.isSuspicious)
    }

    /// Verifies transparent edges are not flagged as suspicious.
    func testTransparentBorderIsNotSuspicious() throws {
        let url = try writeFixturePNG(
            named: "transparent-border",
            width: 3,
            height: 3,
            pixels: [
                .transparent, .transparent, .transparent,
                .transparent, .opaqueRed, .transparent,
                .transparent, .transparent, .transparent
            ]
        )

        let inspection = try ScreenAuditTransparencyInspector().inspectOpaqueBorder(at: url)

        XCTAssertEqual(inspection.edgePixelCount, 8)
        XCTAssertEqual(inspection.opaqueEdgePixelCount, 0)
        XCTAssertEqual(inspection.transparentInteriorPixelCount, 0)
        XCTAssertFalse(inspection.isSuspicious)
    }

    /// Verifies fully opaque images are not treated as matte-border failures.
    func testFullyOpaqueImageIsNotSuspiciousWithoutTransparentInterior() throws {
        let url = try writeFixturePNG(
            named: "fully-opaque",
            width: 3,
            height: 3,
            pixels: Array(repeating: .opaqueRed, count: 9)
        )

        let inspection = try ScreenAuditTransparencyInspector().inspectOpaqueBorder(at: url)

        XCTAssertEqual(inspection.opaqueEdgeRatio, 1.0)
        XCTAssertEqual(inspection.transparentInteriorPixelCount, 0)
        XCTAssertFalse(inspection.isSuspicious)
    }

    /// Verifies suspicious inspections can be converted into warning findings.
    func testSuspiciousInspectionCreatesFinding() throws {
        let inspection = ScreenAuditOpaqueBorderInspection(
            edgePixelCount: 8,
            opaqueEdgePixelCount: 8,
            transparentInteriorPixelCount: 1,
            opaqueEdgeRatio: 1.0,
            isSuspicious: true
        )

        let finding = try XCTUnwrap(
            ScreenAuditTransparencyInspector().findingIfNeeded(
                inspection: inspection,
                screenID: "asset",
                path: "asset.png"
            )
        )

        XCTAssertEqual(finding.ruleID, .suspiciousOpaqueBorder)
        XCTAssertEqual(finding.severity, .warning)
        XCTAssertEqual(finding.confidence, 0.8)
        XCTAssertTrue(finding.evidence.excerpt.contains("8/8 edge pixels opaque"))
    }

    private func writeFixturePNG(
        named name: String,
        width: Int,
        height: Int,
        pixels: [AlphaFixturePixel]
    ) throws -> URL {
        XCTAssertEqual(pixels.count, width * height)
        let directory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("transparency")
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

private enum AlphaFixturePixel {
    case opaqueRed
    case transparent

    var rgba: [UInt8] {
        switch self {
        case .opaqueRed:
            [255, 0, 0, 255]
        case .transparent:
            [0, 0, 0, 0]
        }
    }
}
