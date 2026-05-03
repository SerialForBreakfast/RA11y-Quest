import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Vision-backed OCR used by ``ScreenAuditImageEvidenceExtractor`` when the CLI selects `--ocr vision`.
///
/// Runs on the caller's thread; safe to invoke from ``ScreenAuditValidator`` during filesystem validation.
/// Requires macOS with the Vision framework (see ``ScreenAuditKit`` package platform).
/// Recognition is pinned to `en-US` with language correction off so short UI tokens match RA11y contracts
/// more predictably than fully automatic multilingual detection.
public struct ScreenAuditVisionOCRRecognizer: ScreenAuditOCRRecognizing {
    /// Creates a Vision OCR recognizer.
    public init() {}

    /// Performs text recognition on PNG data and joins top candidate strings in reading order.
    public func recognizeText(inPNGData data: Data, path: String) throws -> ScreenAuditOCRTranscript {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ScreenAuditEvidenceError.unreadableImage(path: path)
        }

        let imageType = CGImageSourceGetType(source) as String?
        guard imageType == "public.png" else {
            throw ScreenAuditEvidenceError.unsupportedImageType(path: path, actualType: imageType)
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScreenAuditEvidenceError.missingImageProperties(path: path)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Prefer English for RA11y UI copy; disable correction for more literal glyph matching on short tokens.
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw ScreenAuditEvidenceError.ocrFailed(path: path, reason: error.localizedDescription)
        }

        guard let observations = request.results else {
            return ScreenAuditOCRTranscript()
        }

        let lines = observations.compactMap { observation -> String? in
            observation.topCandidates(1).first?.string
        }

        let fullText = lines.joined(separator: "\n")
        return ScreenAuditOCRTranscript(fullText: fullText)
    }
}
