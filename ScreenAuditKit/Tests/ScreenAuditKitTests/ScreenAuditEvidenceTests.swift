import Foundation
import XCTest
@testable import ScreenAuditKit

/// Tests PNG metadata evidence extraction.
final class ScreenAuditEvidenceTests: XCTestCase {
    /// Verifies PNG data extraction preserves screen ID, dimensions, alpha, path, and OCR output.
    func testExtractPNGDataReturnsMetadataAndInjectedOCRTranscript() throws {
        let extractor = ScreenAuditImageEvidenceExtractor(
            ocrRecognizer: FixtureOCRRecognizer(transcript: "Quest Board")
        )

        let evidence = try extractor.extractPNG(
            data: try transparentPixelPNGData(),
            path: "fixture.png",
            screenID: "hub"
        )

        XCTAssertEqual(evidence.screenID, "hub")
        XCTAssertEqual(evidence.path, "fixture.png")
        XCTAssertEqual(evidence.pixelWidth, 1)
        XCTAssertEqual(evidence.pixelHeight, 1)
        XCTAssertTrue(evidence.hasAlpha)
        XCTAssertEqual(evidence.ocrTranscript.fullText, "Quest Board")
    }

    /// Verifies PNG path extraction reads explicit files and preserves their paths.
    func testExtractPNGAtPathReturnsMetadata() throws {
        let pngURL = try writeFixturePNGToBuildDirectory()
        let extractor = ScreenAuditImageEvidenceExtractor()

        let evidence = try extractor.extractPNG(at: pngURL, screenID: "pixel")

        XCTAssertEqual(evidence.screenID, "pixel")
        XCTAssertEqual(evidence.path, pngURL.path)
        XCTAssertEqual(evidence.pixelWidth, 1)
        XCTAssertEqual(evidence.pixelHeight, 1)
        XCTAssertTrue(evidence.hasAlpha)
        XCTAssertEqual(evidence.ocrTranscript.fullText, "")
    }

    /// Verifies non-PNG inputs fail before metadata extraction proceeds.
    func testNonPNGDataThrowsUnsupportedImageType() throws {
        let extractor = ScreenAuditImageEvidenceExtractor()
        let path = "not-a-png.txt"
        let data = try XCTUnwrap("not an image".data(using: .utf8))

        XCTAssertThrowsError(try extractor.extractPNG(data: data, path: path, screenID: "bad")) { error in
            XCTAssertEqual(
                error as? ScreenAuditEvidenceError,
                .unsupportedImageType(path: path, actualType: nil)
            )
        }
    }

    /// Verifies missing path inputs fail as file access errors.
    func testMissingPNGPathThrowsUnreadableImage() throws {
        let extractor = ScreenAuditImageEvidenceExtractor()
        let missingURL = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("missing.png")

        XCTAssertThrowsError(try extractor.extractPNG(at: missingURL, screenID: "missing")) { error in
            XCTAssertEqual(
                error as? ScreenAuditEvidenceError,
                .unreadableImage(path: missingURL.path)
            )
        }
    }

    /// Decodes a tiny transparent PNG fixture.
    /// - Returns: PNG data.
    private func transparentPixelPNGData() throws -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        return try XCTUnwrap(Data(base64Encoded: base64))
    }

    /// Writes the fixture PNG under the package build directory for path-based tests.
    /// - Returns: File URL for the written PNG.
    private func writeFixturePNGToBuildDirectory() throws -> URL {
        let outputDirectory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let outputURL = outputDirectory.appendingPathComponent("transparent-pixel.png")
        try transparentPixelPNGData().write(to: outputURL, options: .atomic)
        return outputURL
    }

    /// Resolves the package root from this source file path.
    /// - Returns: Package root URL.
    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

/// OCR recognizer fixture that returns a stable transcript.
private struct FixtureOCRRecognizer: ScreenAuditOCRRecognizing {
    /// Transcript returned for every image.
    let transcript: String

    /// Returns the configured transcript.
    /// - Parameters:
    ///   - data: PNG image data.
    ///   - path: Source path for diagnostics.
    /// - Returns: OCR transcript.
    func recognizeText(inPNGData data: Data, path: String) throws -> ScreenAuditOCRTranscript {
        ScreenAuditOCRTranscript(fullText: transcript)
    }
}
