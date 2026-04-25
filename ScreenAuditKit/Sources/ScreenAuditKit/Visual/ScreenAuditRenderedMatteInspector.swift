import CoreGraphics
import Foundation
import ImageIO

/// Errors raised while inspecting rendered screenshot regions.
public enum ScreenAuditRenderedMatteError: Error, Equatable, LocalizedError {
    /// The screenshot pixels could not be decoded.
    case pixelDecodeFailed(path: String)

    /// Human-readable error text suitable for CLI output.
    public var errorDescription: String? {
        switch self {
        case let .pixelDecodeFailed(path):
            "Unable to decode pixels for rendered matte inspection: `\(path)`."
        }
    }
}

/// Metrics for flat matte-like color coverage inside a screenshot region.
public struct ScreenAuditRenderedMatteInspection: Codable, Equatable, Sendable {
    /// Region inspected.
    public let region: ScreenAuditRegion

    /// Number of pixels inspected inside the region.
    public let inspectedPixels: Int

    /// Number of pixels matching matte-like colors.
    public let matteLikePixels: Int

    /// Ratio of matte-like pixels to inspected pixels.
    public let matteLikeRatio: Double

    /// Whether the region meets the rendered matte risk heuristic.
    public let isRisk: Bool

    /// Creates rendered matte inspection metrics.
    /// - Parameters:
    ///   - region: Region inspected.
    ///   - inspectedPixels: Number of pixels inspected inside the region.
    ///   - matteLikePixels: Number of pixels matching matte-like colors.
    ///   - matteLikeRatio: Ratio of matte-like pixels to inspected pixels.
    ///   - isRisk: Whether the region meets the rendered matte risk heuristic.
    public init(
        region: ScreenAuditRegion,
        inspectedPixels: Int,
        matteLikePixels: Int,
        matteLikeRatio: Double,
        isRisk: Bool
    ) {
        self.region = region
        self.inspectedPixels = inspectedPixels
        self.matteLikePixels = matteLikePixels
        self.matteLikeRatio = matteLikeRatio
        self.isRisk = isRisk
    }
}

/// Inspects critical screenshot regions for large flat white/black/gray matte blocks.
public struct ScreenAuditRenderedMatteInspector {
    /// Creates a rendered matte inspector.
    public init() {}

    /// Inspects a screenshot region for matte-like color coverage.
    /// - Parameters:
    ///   - url: Screenshot PNG URL.
    ///   - region: Critical region to inspect.
    ///   - minimumMatteLikeRatio: Minimum coverage required to flag the region.
    /// - Returns: Rendered matte inspection metrics.
    public func inspect(
        screenshotURL url: URL,
        region: ScreenAuditRegion,
        minimumMatteLikeRatio: Double = 0.85
    ) throws -> ScreenAuditRenderedMatteInspection {
        let image = try MatteInspectableImage(url: url)
        let boundedRegion = region.clamped(toWidth: image.width, height: image.height)

        var inspectedPixels = 0
        var matteLikePixels = 0

        for y in boundedRegion.y..<(boundedRegion.y + boundedRegion.height) {
            for x in boundedRegion.x..<(boundedRegion.x + boundedRegion.width) {
                inspectedPixels += 1
                if image.isMatteLikePixel(x: x, y: y) {
                    matteLikePixels += 1
                }
            }
        }

        let matteLikeRatio = inspectedPixels == 0 ? 0 : Double(matteLikePixels) / Double(inspectedPixels)
        let isRisk = inspectedPixels > 0 && matteLikeRatio >= minimumMatteLikeRatio

        return ScreenAuditRenderedMatteInspection(
            region: boundedRegion,
            inspectedPixels: inspectedPixels,
            matteLikePixels: matteLikePixels,
            matteLikeRatio: matteLikeRatio,
            isRisk: isRisk
        )
    }

    /// Builds a finding when a region looks like a rendered matte block.
    /// - Parameters:
    ///   - inspection: Rendered matte inspection metrics.
    ///   - screenID: Screen identifier.
    ///   - path: Screenshot path.
    ///   - severity: Finding severity.
    /// - Returns: Finding when the region is risky.
    public func findingIfNeeded(
        inspection: ScreenAuditRenderedMatteInspection,
        screenID: String,
        path: String,
        severity: ScreenAuditSeverity = .warning
    ) -> ScreenAuditFinding? {
        guard inspection.isRisk else {
            return nil
        }

        return ScreenAuditFinding(
            ruleID: .renderedMatteRisk,
            severity: severity,
            confidence: 0.7,
            message: "Critical region `\(inspection.region.name)` contains a large flat white, black, or gray block that may indicate a rendered matte artifact.",
            evidence: ScreenAuditEvidenceReference(
                screenID: screenID,
                path: path,
                excerpt: "\(inspection.matteLikePixels)/\(inspection.inspectedPixels) matte-like pixels"
            )
        )
    }
}

private struct MatteInspectableImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(url: URL) throws {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenAuditRenderedMatteError.pixelDecodeFailed(path: url.path)
        }

        width = image.width
        height = image.height

        var mutableBytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &mutableBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenAuditRenderedMatteError.pixelDecodeFailed(path: url.path)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = mutableBytes
    }

    func isMatteLikePixel(x: Int, y: Int) -> Bool {
        let offset = ((y * width) + x) * 4
        let red = Int(bytes[offset])
        let green = Int(bytes[offset + 1])
        let blue = Int(bytes[offset + 2])
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let isNearlyNeutral = maxChannel - minChannel <= 8
        let isWhiteBlackOrMidGray = maxChannel >= 245 || maxChannel <= 10 || (maxChannel >= 120 && maxChannel <= 190)
        return isNearlyNeutral && isWhiteBlackOrMidGray
    }
}

private extension ScreenAuditRegion {
    func clamped(toWidth imageWidth: Int, height imageHeight: Int) -> ScreenAuditRegion {
        let clampedX = max(0, min(x, imageWidth))
        let clampedY = max(0, min(y, imageHeight))
        let maxWidth = max(0, imageWidth - clampedX)
        let maxHeight = max(0, imageHeight - clampedY)
        return ScreenAuditRegion(
            name: name,
            x: clampedX,
            y: clampedY,
            width: max(0, min(width, maxWidth)),
            height: max(0, min(height, maxHeight))
        )
    }
}
