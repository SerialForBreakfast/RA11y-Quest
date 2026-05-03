import AppKit
import Foundation
import XCTest
@testable import ScreenAuditKit

/// Tests live Vision OCR against synthetic PNGs (AppKit-rendered text; no shipped quest art).
final class ScreenAuditVisionOCRRecognizerTests: XCTestCase {
    /// Verifies Vision returns a transcript containing a known rendered phrase.
    func testRecognizesRenderedPhrase() throws {
        let phrase = "OCRFIX42"
        let data = try Self.pngDataDrawingBlackText(phrase)
        let transcript = try ScreenAuditVisionOCRRecognizer().recognizeText(inPNGData: data, path: "synthetic.png")
        let normalized = transcript.fullText
            .replacingOccurrences(of: "\n", with: " ")
            .uppercased()
        XCTAssertTrue(
            normalized.contains(phrase),
            "Expected OCR to include `\(phrase)`; transcript was: \(transcript.fullText.debugDescription)"
        )
    }

    /// Verifies ``ScreenAuditImageEvidenceExtractor`` wired to Vision propagates OCR into evidence.
    func testExtractorWithVisionPropagatesTranscript() throws {
        let phrase = "OCRFIX42"
        let data = try Self.pngDataDrawingBlackText(phrase)
        let extractor = ScreenAuditImageEvidenceExtractor(ocrRecognizer: ScreenAuditVisionOCRRecognizer())
        let evidence = try extractor.extractPNG(data: data, path: "fixture.png", screenID: "fixture")
        let normalized = evidence.ocrTranscript.fullText
            .replacingOccurrences(of: "\n", with: " ")
            .uppercased()
        XCTAssertTrue(normalized.contains(phrase), evidence.ocrTranscript.fullText)
    }

    /// Renders black-on-white text into a PNG using AppKit so Vision sees a typical UI bitmap.
    private static func pngDataDrawingBlackText(_ text: String) throws -> Data {
        let size = NSSize(width: 800, height: 220)
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor.white.setFill()
            bounds.fill()
            let font = NSFont.monospacedSystemFont(ofSize: 80, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
                .kern: 6,
            ]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            let origin = NSPoint(x: 48, y: (bounds.height - attributed.size().height) / 2)
            attributed.draw(at: origin)
            return true
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            struct EncodeError: Error {}
            throw EncodeError()
        }
        return png
    }
}
