import CoreGraphics
import Foundation
import ImageIO

/// Errors raised while inspecting PNG transparency.
public enum ScreenAuditTransparencyError: Error, Equatable, LocalizedError {
    /// The image could not be decoded as RGBA pixels.
    case pixelDecodeFailed(path: String)

    /// Human-readable error text suitable for CLI output.
    public var errorDescription: String? {
        switch self {
        case let .pixelDecodeFailed(path):
            "Unable to decode pixels for transparency inspection: `\(path)`."
        }
    }
}

/// Metrics describing alpha values on a PNG border and interior.
public struct ScreenAuditOpaqueBorderInspection: Codable, Equatable, Sendable {
    /// Number of pixels on the outer image edge.
    public let edgePixelCount: Int

    /// Number of edge pixels with fully opaque alpha.
    public let opaqueEdgePixelCount: Int

    /// Number of non-edge pixels with transparent alpha.
    public let transparentInteriorPixelCount: Int

    /// Ratio of fully opaque edge pixels to all edge pixels.
    public let opaqueEdgeRatio: Double

    /// Whether the metrics meet the suspicious opaque-border heuristic.
    public let isSuspicious: Bool

    /// Creates opaque-border inspection metrics.
    /// - Parameters:
    ///   - edgePixelCount: Number of pixels on the outer image edge.
    ///   - opaqueEdgePixelCount: Number of edge pixels with fully opaque alpha.
    ///   - transparentInteriorPixelCount: Number of non-edge pixels with transparent alpha.
    ///   - opaqueEdgeRatio: Ratio of fully opaque edge pixels to all edge pixels.
    ///   - isSuspicious: Whether the metrics meet the suspicious opaque-border heuristic.
    public init(
        edgePixelCount: Int,
        opaqueEdgePixelCount: Int,
        transparentInteriorPixelCount: Int,
        opaqueEdgeRatio: Double,
        isSuspicious: Bool
    ) {
        self.edgePixelCount = edgePixelCount
        self.opaqueEdgePixelCount = opaqueEdgePixelCount
        self.transparentInteriorPixelCount = transparentInteriorPixelCount
        self.opaqueEdgeRatio = opaqueEdgeRatio
        self.isSuspicious = isSuspicious
    }
}

/// Inspects PNG alpha edges for rectangular matte symptoms.
public struct ScreenAuditTransparencyInspector {
    /// Creates a transparency inspector.
    public init() {}

    /// Inspects whether a PNG has suspicious fully opaque edges around transparent interior pixels.
    /// - Parameters:
    ///   - url: PNG file URL.
    ///   - minimumOpaqueEdgeRatio: Minimum opaque-edge ratio required to flag suspicion.
    /// - Returns: Opaque-border inspection metrics.
    public func inspectOpaqueBorder(
        at url: URL,
        minimumOpaqueEdgeRatio: Double = 0.95
    ) throws -> ScreenAuditOpaqueBorderInspection {
        let image = try AlphaInspectableImage(url: url)
        guard image.width > 0, image.height > 0 else {
            throw ScreenAuditTransparencyError.pixelDecodeFailed(path: url.path)
        }

        var edgePixelCount = 0
        var opaqueEdgePixelCount = 0
        var transparentInteriorPixelCount = 0

        for y in 0..<image.height {
            for x in 0..<image.width {
                let alpha = image.alphaAt(x: x, y: y)
                if x == 0 || y == 0 || x == image.width - 1 || y == image.height - 1 {
                    edgePixelCount += 1
                    if alpha == 255 {
                        opaqueEdgePixelCount += 1
                    }
                } else if alpha == 0 {
                    transparentInteriorPixelCount += 1
                }
            }
        }

        let opaqueEdgeRatio = edgePixelCount == 0 ? 0 : Double(opaqueEdgePixelCount) / Double(edgePixelCount)
        let isSuspicious = opaqueEdgeRatio >= minimumOpaqueEdgeRatio && transparentInteriorPixelCount > 0

        return ScreenAuditOpaqueBorderInspection(
            edgePixelCount: edgePixelCount,
            opaqueEdgePixelCount: opaqueEdgePixelCount,
            transparentInteriorPixelCount: transparentInteriorPixelCount,
            opaqueEdgeRatio: opaqueEdgeRatio,
            isSuspicious: isSuspicious
        )
    }

    /// Builds a finding when inspection metrics indicate a suspicious opaque border.
    /// - Parameters:
    ///   - inspection: Opaque-border inspection metrics.
    ///   - screenID: Identifier to associate with the inspected image.
    ///   - path: Source PNG path.
    ///   - severity: Finding severity.
    /// - Returns: Finding when the image looks suspicious.
    public func findingIfNeeded(
        inspection: ScreenAuditOpaqueBorderInspection,
        screenID: String,
        path: String,
        severity: ScreenAuditSeverity = .warning
    ) -> ScreenAuditFinding? {
        guard inspection.isSuspicious else {
            return nil
        }

        return ScreenAuditFinding(
            ruleID: .suspiciousOpaqueBorder,
            severity: severity,
            confidence: 0.8,
            message: "PNG has fully opaque edges around transparent interior pixels, which can indicate a rectangular matte or bad alpha cleanup.",
            evidence: ScreenAuditEvidenceReference(
                screenID: screenID,
                path: path,
                excerpt: "\(inspection.opaqueEdgePixelCount)/\(inspection.edgePixelCount) edge pixels opaque; \(inspection.transparentInteriorPixelCount) transparent interior pixels"
            )
        )
    }
}

private struct AlphaInspectableImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(url: URL) throws {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenAuditTransparencyError.pixelDecodeFailed(path: url.path)
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
            throw ScreenAuditTransparencyError.pixelDecodeFailed(path: url.path)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = mutableBytes
    }

    func alphaAt(x: Int, y: Int) -> UInt8 {
        bytes[((y * width) + x) * 4 + 3]
    }
}
