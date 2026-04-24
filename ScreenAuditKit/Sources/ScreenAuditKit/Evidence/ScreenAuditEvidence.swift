import CoreGraphics
import Foundation
import ImageIO

/// Errors raised while reading screenshot evidence.
public enum ScreenAuditEvidenceError: Error, Equatable, LocalizedError {
    /// The requested screenshot file could not be read.
    case unreadableImage(path: String)

    /// The requested screenshot is not a PNG image.
    case unsupportedImageType(path: String, actualType: String?)

    /// The PNG image could not be decoded into pixel metadata.
    case missingImageProperties(path: String)

    /// Human-readable error text suitable for CLI and report output.
    public var errorDescription: String? {
        switch self {
        case let .unreadableImage(path):
            "Unable to read screenshot image at `\(path)`."
        case let .unsupportedImageType(path, actualType):
            "Screenshot image at `\(path)` must be a PNG. Actual type: \(actualType ?? "unknown")."
        case let .missingImageProperties(path):
            "Unable to decode PNG metadata for screenshot image at `\(path)`."
        }
    }
}

/// Structured evidence extracted from one screenshot image.
public struct ScreenAuditScreenshotEvidence: Codable, Equatable, Sendable {
    /// Stable screen identifier from the matching contract.
    public let screenID: String

    /// Path used to read the screenshot.
    public let path: String

    /// Decoded image width in pixels.
    public let pixelWidth: Int

    /// Decoded image height in pixels.
    public let pixelHeight: Int

    /// Whether the decoded image has an alpha channel.
    public let hasAlpha: Bool

    /// OCR transcript associated with this screenshot.
    public let ocrTranscript: ScreenAuditOCRTranscript

    /// Creates screenshot evidence.
    /// - Parameters:
    ///   - screenID: Stable screen identifier from the matching contract.
    ///   - path: Path used to read the screenshot.
    ///   - pixelWidth: Decoded image width in pixels.
    ///   - pixelHeight: Decoded image height in pixels.
    ///   - hasAlpha: Whether the decoded image has an alpha channel.
    ///   - ocrTranscript: OCR transcript associated with this screenshot.
    public init(
        screenID: String,
        path: String,
        pixelWidth: Int,
        pixelHeight: Int,
        hasAlpha: Bool,
        ocrTranscript: ScreenAuditOCRTranscript = ScreenAuditOCRTranscript()
    ) {
        self.screenID = screenID
        self.path = path
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.hasAlpha = hasAlpha
        self.ocrTranscript = ocrTranscript
    }
}

/// OCR transcript extracted from a screenshot.
public struct ScreenAuditOCRTranscript: Codable, Equatable, Sendable {
    /// Full transcript text in reading order, when known.
    public let fullText: String

    /// Creates an OCR transcript.
    /// - Parameter fullText: Full transcript text in reading order, when known.
    public init(fullText: String = "") {
        self.fullText = fullText
    }
}

/// Narrow OCR boundary used by screenshot evidence extraction.
public protocol ScreenAuditOCRRecognizing {
    /// Extracts OCR text from PNG screenshot data.
    /// - Parameters:
    ///   - data: PNG image data.
    ///   - path: Source path for diagnostics.
    /// - Returns: OCR transcript for the screenshot.
    func recognizeText(inPNGData data: Data, path: String) throws -> ScreenAuditOCRTranscript
}

/// OCR recognizer that intentionally returns an empty transcript.
public struct ScreenAuditNoOpOCRRecognizer: ScreenAuditOCRRecognizing {
    /// Creates a no-op OCR recognizer.
    public init() {}

    /// Returns an empty transcript without inspecting the image.
    /// - Parameters:
    ///   - data: PNG image data.
    ///   - path: Source path for diagnostics.
    /// - Returns: Empty OCR transcript.
    public func recognizeText(inPNGData data: Data, path: String) throws -> ScreenAuditOCRTranscript {
        ScreenAuditOCRTranscript()
    }
}

/// Extracts deterministic screenshot evidence from PNG data.
public struct ScreenAuditImageEvidenceExtractor {
    private let ocrRecognizer: any ScreenAuditOCRRecognizing

    /// Creates an image evidence extractor.
    /// - Parameter ocrRecognizer: OCR service used after PNG metadata is decoded.
    public init(ocrRecognizer: any ScreenAuditOCRRecognizing = ScreenAuditNoOpOCRRecognizer()) {
        self.ocrRecognizer = ocrRecognizer
    }

    /// Loads a PNG file from disk and extracts screenshot evidence.
    /// - Parameters:
    ///   - url: Screenshot file URL.
    ///   - screenID: Stable screen identifier from the matching contract.
    /// - Returns: Structured screenshot evidence.
    public func extractPNG(at url: URL, screenID: String) throws -> ScreenAuditScreenshotEvidence {
        let path = url.path
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ScreenAuditEvidenceError.unreadableImage(path: path)
        }

        return try extractPNG(data: data, path: path, screenID: screenID)
    }

    /// Extracts screenshot evidence from PNG data.
    /// - Parameters:
    ///   - data: PNG image data.
    ///   - path: Source path for diagnostics and reports.
    ///   - screenID: Stable screen identifier from the matching contract.
    /// - Returns: Structured screenshot evidence.
    public func extractPNG(data: Data, path: String, screenID: String) throws -> ScreenAuditScreenshotEvidence {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ScreenAuditEvidenceError.unreadableImage(path: path)
        }

        let imageType = CGImageSourceGetType(source) as String?
        guard imageType == "public.png" else {
            throw ScreenAuditEvidenceError.unsupportedImageType(path: path, actualType: imageType)
        }

        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenAuditEvidenceError.missingImageProperties(path: path)
        }

        let transcript = try ocrRecognizer.recognizeText(inPNGData: data, path: path)

        return ScreenAuditScreenshotEvidence(
            screenID: screenID,
            path: path,
            pixelWidth: width,
            pixelHeight: height,
            hasAlpha: image.alphaInfo.hasAlpha,
            ocrTranscript: transcript
        )
    }
}

private extension CGImageAlphaInfo {
    /// Whether a CoreGraphics alpha value represents an image with alpha.
    var hasAlpha: Bool {
        switch self {
        case .premultipliedLast, .premultipliedFirst, .last, .first:
            true
        case .none, .noneSkipLast, .noneSkipFirst, .alphaOnly:
            false
        @unknown default:
            false
        }
    }
}
