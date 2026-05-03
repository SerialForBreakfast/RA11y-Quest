import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenAuditKit

/// Tests human-readable ScreenAuditKit report output.
final class ScreenAuditReportTests: XCTestCase {
    /// Verifies findings summaries include reviewer guidance, not only raw rule data.
    func testMarkdownSummaryIncludesReviewGuidance() {
        let report = ScreenAuditFindingsReport(
            projectName: "Report Fixture",
            findings: [
                ScreenAuditFinding(
                    ruleID: .renderedMatteRisk,
                    severity: .warning,
                    confidence: 0.7,
                    message: "Region `critical-art` appears flat.",
                    evidence: ScreenAuditEvidenceReference(
                        screenID: "banishment",
                        path: "screen.png",
                        excerpt: "critical-art"
                    )
                ),
                ScreenAuditFinding(
                    ruleID: .textRulesSkipped,
                    severity: .info,
                    confidence: 1.0,
                    message: "Skipped 1 required and 0 forbidden text rule(s) because OCR was not requested.",
                    evidence: ScreenAuditEvidenceReference(
                        screenID: "hub",
                        path: "01_Hub.png",
                        excerpt: "required=RA11y"
                    )
                )
            ]
        )

        let markdown = ScreenAuditReportWriter().markdownSummary(for: report)

        XCTAssertTrue(markdown.contains("## Review Queue"))
        XCTAssertTrue(markdown.contains("Why it matters"))
        XCTAssertTrue(markdown.contains("Suggested next step"))
        XCTAssertTrue(markdown.contains("## Rule Guide"))
        XCTAssertTrue(markdown.contains("Inspect the highlighted critical region"))
        XCTAssertTrue(markdown.contains("- Warnings: 1"))
        XCTAssertTrue(markdown.contains("- Info: 1"))
        XCTAssertTrue(markdown.contains("- Hard failures (error): 0"))
        XCTAssertTrue(markdown.contains("## Where to look next"))
        XCTAssertTrue(markdown.contains("`overlays/`"))
        XCTAssertTrue(markdown.contains("textRulesSkipped"))
        XCTAssertTrue(markdown.contains("Run the audit again with `--ocr vision`"))
    }

    /// Verifies flow documentation is referenced in the summary when flows are part of the run.
    func testMarkdownSummaryMentionsFlowDocsWhenConfigured() {
        let report = ScreenAuditFindingsReport(projectName: "Flow Doc Fixture", findings: [])
        let markdown = ScreenAuditReportWriter().markdownSummary(
            for: report,
            includesFlowDocumentation: true
        )

        XCTAssertTrue(markdown.contains("flow-summary.md"))
        XCTAssertTrue(markdown.contains("flow.json"))
    }

    /// Verifies overlay Markdown explains the colored rectangles and review intent.
    func testOverlayMarkdownIncludesLegendAndRegionPurpose() throws {
        let directory = try makeFixtureDirectory(named: "overlay-markdown")
        let screenshotsDirectory = directory.appendingPathComponent("screenshots")
        let outputDirectory = directory.appendingPathComponent("reports")
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)

        try writePNG(
            width: 4,
            height: 4,
            pixels: Array(repeating: .gray, count: 16),
            to: screenshotsDirectory.appendingPathComponent("screen.png")
        )

        let contractFile = directory.appendingPathComponent("contracts.json")
        try """
        {
          "schemaVersion": 1,
          "projectName": "Overlay Fixture",
          "screens": [
            {
              "id": "screen",
              "filename": "screen.png",
              "devices": [
                { "label": "fixture", "pixelWidth": 5, "pixelHeight": 5 }
              ],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "regions": {
                "protected": [
                  { "name": "title", "x": 0, "y": 0, "width": 2, "height": 2 }
                ],
                "ignored": [
                  { "name": "volatile", "x": 2, "y": 0, "width": 2, "height": 2 }
                ],
                "critical": [
                  { "name": "art", "x": 0, "y": 2, "width": 2, "height": 2 }
                ]
              },
              "severityOverrides": {}
            }
          ]
        }
        """.write(to: contractFile, atomically: true, encoding: .utf8)

        _ = try ScreenAuditValidator().validate(
            screenshotsDirectory: screenshotsDirectory,
            contractFile: contractFile,
            outputDirectory: outputDirectory
        )

        let overlayMarkdownURL = outputDirectory
            .appendingPathComponent("overlays")
            .appendingPathComponent("screen-overlay.md")
        let markdown = try String(contentsOf: overlayMarkdownURL, encoding: .utf8)

        XCTAssertTrue(markdown.contains("## How to Read This Overlay"))
        XCTAssertTrue(markdown.contains("A rectangle is not automatically the failing pixel"))
        XCTAssertTrue(markdown.contains("| Red | critical / screenshot |"))
        XCTAssertTrue(markdown.contains("| Blue | protected |"))
        XCTAssertTrue(markdown.contains("| Amber | ignored |"))
        XCTAssertTrue(markdown.contains("High-value visual content checked"))
    }

    /// Verifies flow summaries include an advisory Mermaid graph for reviewer orientation.
    func testMarkdownFlowSummaryIncludesMermaidBlock() {
        let flowReport = ScreenAuditFlowReport(
            projectName: "Mermaid Fixture",
            flows: [
                ScreenAuditFlowResult(
                    id: "onboarding",
                    title: "Onboarding",
                    steps: [
                        ScreenAuditFlowStepResult(index: 0, screenID: "entry", required: true, status: .present),
                        ScreenAuditFlowStepResult(index: 1, screenID: "ready", required: true, status: .present),
                    ]
                ),
            ]
        )

        let markdown = ScreenAuditReportWriter().markdownFlowSummary(for: flowReport)

        XCTAssertTrue(markdown.contains("```mermaid"))
        XCTAssertTrue(markdown.contains("flowchart LR"))
        XCTAssertTrue(markdown.contains("entry"))
        XCTAssertTrue(markdown.contains("ready"))
    }

    private func makeFixtureDirectory(named name: String) throws -> URL {
        let directory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("reports")
            .appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writePNG(width: Int, height: Int, pixels: [FixturePixel], to url: URL) throws {
        XCTAssertEqual(pixels.count, width * height)
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
    }

    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private enum FixturePixel {
    case gray

    var rgba: [UInt8] {
        switch self {
        case .gray:
            [120, 120, 120, 255]
        }
    }
}
