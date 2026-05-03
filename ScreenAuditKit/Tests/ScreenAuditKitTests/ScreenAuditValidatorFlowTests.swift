import Foundation
import XCTest
@testable import ScreenAuditKit

/// Integration tests: ``ScreenAuditValidator`` filesystem path matches ``ScreenAuditFlowEvaluator`` semantics
/// (evidence excludes missing PNGs; flow findings merge into the final report).
final class ScreenAuditValidatorFlowTests: XCTestCase {
    /// Verifies a missing first screenshot still drives `flowPreviousStepMissing` when the second step requires co-presence.
    func testMissingFirstPngMergesMissingScreenshotAndFlowFindings() throws {
        let root = try makeFixtureRoot(named: "validator-flow-missing-alpha")
        let screenshots = root.appendingPathComponent("shots")
        let output = root.appendingPathComponent("out")
        let contractURL = root.appendingPathComponent("contracts.json")
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        try flowTwoStepContractJSON().write(to: contractURL, atomically: true, encoding: .utf8)
        try transparentPixelPNGData().write(to: screenshots.appendingPathComponent("02_Beta.png"), options: .atomic)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: screenshots,
            contractFile: contractURL,
            outputDirectory: output
        )

        let ruleIDs = Set(result.findingsReport.findings.map(\.ruleID))
        XCTAssertTrue(ruleIDs.contains(.missingScreenshot))
        XCTAssertTrue(ruleIDs.contains(.flowMissingRequiredStep))
        XCTAssertTrue(ruleIDs.contains(.flowPreviousStepMissing))

        XCTAssertEqual(result.flowReport.flows.count, 1)
        XCTAssertEqual(result.flowReport.flows.first?.steps.map(\.status), [.missing, .present])

        let flowData = try Data(contentsOf: output.appendingPathComponent("flow.json"))
        let decodedFlow = try JSONDecoder().decode(ScreenAuditFlowReport.self, from: flowData)
        XCTAssertEqual(decodedFlow, result.flowReport)
    }

    /// Verifies both screenshots present yields no flow-related findings and a fully-present flow report.
    func testBothPngsPresentProducesCleanFlowInValidationResult() throws {
        let root = try makeFixtureRoot(named: "validator-flow-both-present")
        let screenshots = root.appendingPathComponent("shots")
        let output = root.appendingPathComponent("out")
        let contractURL = root.appendingPathComponent("contracts.json")
        try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        try flowTwoStepContractJSON().write(to: contractURL, atomically: true, encoding: .utf8)
        let png = try transparentPixelPNGData()
        try png.write(to: screenshots.appendingPathComponent("01_Alpha.png"), options: .atomic)
        try png.write(to: screenshots.appendingPathComponent("02_Beta.png"), options: .atomic)

        let result = try ScreenAuditValidator().validate(
            screenshotsDirectory: screenshots,
            contractFile: contractURL,
            outputDirectory: output
        )

        let flowRuleIDs: Set<ScreenAuditRuleID> = [
            .flowUnknownStep,
            .flowMissingRequiredStep,
            .flowDuplicateStep,
            .flowPreviousStepMissing,
        ]
        let flowFindings = result.findingsReport.findings.filter { flowRuleIDs.contains($0.ruleID) }
        XCTAssertTrue(flowFindings.isEmpty, "Unexpected flow findings: \(flowFindings.map(\.ruleID))")

        XCTAssertEqual(result.flowReport.flows.first?.steps.map(\.status), [.present, .present])
    }

    /// Minimal two-screen contract JSON aligned with ``Fixtures/flow-transition-contracts.json`` filenames.
    private func flowTwoStepContractJSON() -> String {
        """
        {
          "schemaVersion": 1,
          "projectName": "Validator flow fixture",
          "screens": [
            {
              "id": "alpha",
              "filename": "01_Alpha.png",
              "devices": [{ "label": "fixture", "pixelWidth": 1, "pixelHeight": 1 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            },
            {
              "id": "beta",
              "filename": "02_Beta.png",
              "devices": [{ "label": "fixture", "pixelWidth": 1, "pixelHeight": 1 }],
              "text": { "required": [], "optional": [], "forbidden": [] },
              "severityOverrides": {}
            }
          ],
          "flows": [
            {
              "id": "sequence",
              "title": "Alpha then Beta",
              "steps": [
                { "screenID": "alpha" },
                { "screenID": "beta", "requirePreviousStepPresent": true }
              ]
            }
          ]
        }
        """
    }

    /// Creates a unique fixture directory under the package build tree.
    private func makeFixtureRoot(named name: String) throws -> URL {
        let root = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("validator-flow")
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Same 1×1 transparent PNG bytes as other ScreenAuditKit tests.
    private func transparentPixelPNGData() throws -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        return try XCTUnwrap(Data(base64Encoded: base64))
    }
}
