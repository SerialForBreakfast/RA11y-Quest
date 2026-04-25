import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// Errors raised while rendering screenshot overlays.
public enum ScreenAuditOverlayRenderError: Error, Equatable, LocalizedError {
    /// The screenshot pixels could not be decoded.
    case pixelDecodeFailed(path: String)

    /// The overlay PNG could not be encoded.
    case pngWriteFailed(path: String)

    /// Human-readable error text suitable for CLI output.
    public var errorDescription: String? {
        switch self {
        case let .pixelDecodeFailed(path):
            "Unable to decode pixels for overlay rendering: `\(path)`."
        case let .pngWriteFailed(path):
            "Unable to write overlay PNG: `\(path)`."
        }
    }
}

/// Region annotation rendered into a screenshot overlay.
public struct ScreenAuditOverlayRegion: Codable, Equatable, Sendable {
    /// Region rectangle in screenshot pixel coordinates.
    public let region: ScreenAuditRegion

    /// Overlay role used to choose a deterministic stroke color.
    public let role: ScreenAuditOverlayRegionRole

    /// Short label drawn near the region and included in sidecar output.
    public let label: String

    /// Creates an overlay region annotation.
    /// - Parameters:
    ///   - region: Region rectangle in screenshot pixel coordinates.
    ///   - role: Overlay role used to choose a deterministic stroke color.
    ///   - label: Short label drawn near the region and included in sidecar output.
    public init(
        region: ScreenAuditRegion,
        role: ScreenAuditOverlayRegionRole,
        label: String? = nil
    ) {
        self.region = region
        self.role = role
        self.label = label ?? "\(role.rawValue): \(region.name)"
    }
}

/// Machine-readable explanation for one overlay artifact.
public struct ScreenAuditOverlayReport: Codable, Equatable, Sendable {
    /// Report schema version.
    public let reportVersion: Int

    /// Screen identifier represented by the overlay.
    public let screenID: String

    /// Source screenshot path.
    public let screenshotPath: String

    /// Overlay PNG path.
    public let overlayPath: String

    /// Findings that caused this overlay to be written.
    public let findings: [ScreenAuditFinding]

    /// Region annotations drawn onto the overlay.
    public let regions: [ScreenAuditOverlayRegion]

    /// Creates an overlay report.
    /// - Parameters:
    ///   - reportVersion: Report schema version.
    ///   - screenID: Screen identifier represented by the overlay.
    ///   - screenshotPath: Source screenshot path.
    ///   - overlayPath: Overlay PNG path.
    ///   - findings: Findings that caused this overlay to be written.
    ///   - regions: Region annotations drawn onto the overlay.
    public init(
        reportVersion: Int = 1,
        screenID: String,
        screenshotPath: String,
        overlayPath: String,
        findings: [ScreenAuditFinding],
        regions: [ScreenAuditOverlayRegion]
    ) {
        self.reportVersion = reportVersion
        self.screenID = screenID
        self.screenshotPath = screenshotPath
        self.overlayPath = overlayPath
        self.findings = findings
        self.regions = regions
    }
}

/// Overlay annotation role.
public enum ScreenAuditOverlayRegionRole: String, Codable, Equatable, Sendable {
    /// Region should receive stricter visual validation.
    case protected

    /// Region is ignored by broad visual comparisons.
    case ignored

    /// Region is inspected for high-signal visual defects.
    case critical

    /// Full screenshot fallback region used when a finding has no configured rectangle.
    case screenshot
}

/// Renders PNG screenshot overlays for human review of failed regions.
public struct ScreenAuditOverlayRenderer {
    /// Creates an overlay renderer.
    public init() {}

    /// Renders a screenshot overlay with deterministic region strokes.
    /// - Parameters:
    ///   - screenshotURL: Source screenshot PNG.
    ///   - regions: Region annotations to draw.
    ///   - outputURL: Destination overlay PNG.
    public func render(
        screenshotURL: URL,
        regions: [ScreenAuditOverlayRegion],
        outputURL: URL
    ) throws {
        guard
            let source = CGImageSourceCreateWithURL(screenshotURL as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenAuditOverlayRenderError.pixelDecodeFailed(path: screenshotURL.path)
        }

        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenAuditOverlayRenderError.pixelDecodeFailed(path: screenshotURL.path)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setLineJoin(.round)

        for overlayRegion in regions {
            draw(overlayRegion: overlayRegion, width: width, height: height, in: context)
        }

        guard let overlayImage = context.makeImage() else {
            throw ScreenAuditOverlayRenderError.pngWriteFailed(path: outputURL.path)
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
            throw ScreenAuditOverlayRenderError.pngWriteFailed(path: outputURL.path)
        }
        CGImageDestinationAddImage(destination, overlayImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenAuditOverlayRenderError.pngWriteFailed(path: outputURL.path)
        }
    }

    private func draw(
        overlayRegion: ScreenAuditOverlayRegion,
        width: Int,
        height: Int,
        in context: CGContext
    ) {
        let region = overlayRegion.region.clamped(toWidth: width, height: height)
        guard region.width > 0, region.height > 0 else {
            return
        }

        let rect = CGRect(
            x: region.x,
            y: region.y,
            width: region.width,
            height: region.height
        ).insetBy(dx: 1, dy: 1)

        let color = overlayRegion.role.color
        context.setStrokeColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.95)
        context.setLineWidth(CGFloat(max(2, min(width, height) / 120)))
        context.stroke(rect)

        drawLabel(
            overlayRegion.label,
            color: color,
            x: rect.minX + 8,
            y: max(8, rect.minY + 8),
            maxWidth: CGFloat(width) - rect.minX - 16,
            in: context
        )
    }

    private func drawLabel(
        _ label: String,
        color: ScreenAuditOverlayColor,
        x: CGFloat,
        y: CGFloat,
        maxWidth: CGFloat,
        in context: CGContext
    ) {
        let fontSize: CGFloat = 18
        let labelHeight: CGFloat = 30
        let labelWidth = min(maxWidth, max(120, CGFloat(label.count * 10)))
        let background = CGRect(x: x, y: y, width: labelWidth, height: labelHeight)

        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0.72)
        context.fill(background)

        let attributes: [CFString: Any] = [
            kCTFontAttributeName: CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil),
            kCTForegroundColorAttributeName: CGColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        ]
        let attributed = CFAttributedStringCreate(nil, label as CFString, attributes as CFDictionary)
        guard let attributed else {
            return
        }
        let line = CTLineCreateWithAttributedString(attributed)

        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x + 6, y: y + 21)
        CTLineDraw(line, context)
    }
}

private struct ScreenAuditOverlayColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

private extension ScreenAuditOverlayRegionRole {
    var color: ScreenAuditOverlayColor {
        switch self {
        case .protected:
            ScreenAuditOverlayColor(red: 0.0, green: 0.45, blue: 1.0)
        case .ignored:
            ScreenAuditOverlayColor(red: 1.0, green: 0.72, blue: 0.0)
        case .critical:
            ScreenAuditOverlayColor(red: 1.0, green: 0.0, blue: 0.2)
        case .screenshot:
            ScreenAuditOverlayColor(red: 1.0, green: 0.0, blue: 0.2)
        }
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
