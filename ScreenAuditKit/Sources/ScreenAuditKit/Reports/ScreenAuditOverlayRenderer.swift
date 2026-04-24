import CoreGraphics
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

    /// Creates an overlay region annotation.
    /// - Parameters:
    ///   - region: Region rectangle in screenshot pixel coordinates.
    ///   - role: Overlay role used to choose a deterministic stroke color.
    public init(region: ScreenAuditRegion, role: ScreenAuditOverlayRegionRole) {
        self.region = region
        self.role = role
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
