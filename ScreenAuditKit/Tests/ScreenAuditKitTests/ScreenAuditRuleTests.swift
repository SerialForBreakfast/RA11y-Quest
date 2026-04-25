import XCTest
@testable import ScreenAuditKit

/// Tests deterministic rule evaluation.
final class ScreenAuditRuleTests: XCTestCase {
    /// Verifies matching text and dimensions produce no findings.
    func testMatchingContractProducesNoFindings() {
        let contract = makeContract()
        let evidence = makeEvidence(transcript: "Quest Board\nStart")

        let findings = ScreenAuditRuleEvaluator().evaluate(contract: contract, evidence: evidence)

        XCTAssertTrue(findings.isEmpty)
    }

    /// Verifies missing required text returns an error finding with evidence context.
    func testMissingRequiredTextProducesFinding() {
        let contract = makeContract()
        let evidence = makeEvidence(transcript: "Start")

        let findings = ScreenAuditRuleEvaluator().evaluate(contract: contract, evidence: evidence)

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.ruleID, .requiredTextMissing)
        XCTAssertEqual(findings.first?.severity, .error)
        XCTAssertEqual(findings.first?.confidence, 1.0)
        XCTAssertEqual(findings.first?.evidence.screenID, "hub")
        XCTAssertEqual(findings.first?.evidence.path, "01_Hub.png")
    }

    /// Verifies forbidden text returns a finding and can use severity overrides.
    func testForbiddenTextUsesSeverityOverride() {
        let contract = makeContract(severityOverrides: [
            ScreenAuditRuleID.forbiddenTextPresent.rawValue: .warning
        ])
        let evidence = makeEvidence(transcript: "Quest Board\nStart\nDebug")

        let findings = ScreenAuditRuleEvaluator().evaluate(contract: contract, evidence: evidence)

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.ruleID, .forbiddenTextPresent)
        XCTAssertEqual(findings.first?.severity, .warning)
        XCTAssertEqual(findings.first?.message, "Forbidden text `Debug` was found.")
    }

    /// Verifies dimension mismatches report actual and expected values.
    func testDimensionMismatchProducesFinding() {
        let contract = makeContract()
        let evidence = makeEvidence(transcript: "Quest Board\nStart", pixelWidth: 100, pixelHeight: 200)

        let findings = ScreenAuditRuleEvaluator().evaluate(contract: contract, evidence: evidence)

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.ruleID, .dimensionMismatch)
        XCTAssertEqual(findings.first?.severity, .error)
        XCTAssertEqual(
            findings.first?.message,
            "Screenshot dimensions were 100x200; expected one of: `iPhone_large` 1290x2796."
        )
        XCTAssertEqual(findings.first?.evidence.excerpt, "100x200")
    }

    /// Verifies multiple device expectations are treated as alternatives.
    func testDimensionRulePassesWhenAnyDeviceExpectationMatches() {
        let contract = ScreenAuditScreenContract(
            id: "hub",
            filename: "01_Hub.png",
            devices: [
                ScreenAuditDeviceExpectation(label: "iPhone_large", pixelWidth: 1206, pixelHeight: 2622),
                ScreenAuditDeviceExpectation(label: "iPad", pixelWidth: 2064, pixelHeight: 2752)
            ],
            text: ScreenAuditTextExpectations(required: ["Quest Board"])
        )
        let evidence = makeEvidence(transcript: "Quest Board", pixelWidth: 2064, pixelHeight: 2752)

        let findings = ScreenAuditRuleEvaluator().evaluate(contract: contract, evidence: evidence)

        XCTAssertTrue(findings.isEmpty)
    }

    /// Verifies low-confidence fallback art facts produce advisory findings.
    func testLowConfidenceFallbackArtProducesFinding() {
        let contract = ScreenAuditScreenContract(
            id: "hub",
            filename: "01_Hub.png",
            assets: ScreenAuditAssetExpectations(
                fallbackArt: [
                    ScreenAuditFallbackArtExpectation(
                        name: "quest-background",
                        confidence: 0.42,
                        minimumConfidence: 0.75,
                        note: "temporary crop from mockup"
                    )
                ]
            )
        )
        let evidence = makeEvidence(transcript: "")
        let provenanceSet = ScreenAuditAssetProvenanceSet(
            assets: [
                ScreenAuditAssetProvenance(
                    id: "quest-background",
                    name: "Quest Background",
                    source: .mockupCrop,
                    authoringStatus: .temporary,
                    sourceQuality: .bootstrap,
                    knownRisks: ["croppedFromScreenshot"]
                )
            ]
        )

        let findings = ScreenAuditRuleEvaluator().evaluate(
            contract: contract,
            evidence: evidence,
            provenanceSet: provenanceSet
        )
        let finding = findings.first

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(finding?.ruleID, .lowConfidenceFallbackArt)
        XCTAssertEqual(finding?.severity, .warning)
        XCTAssertEqual(finding?.confidence ?? -1, 0.58, accuracy: 0.0001)
        XCTAssertEqual(finding?.message, "Fallback art `quest-background` confidence 0.42 is below the required 0.75. Provenance: mockupCrop, temporary, bootstrap.")
        XCTAssertEqual(
            finding?.evidence.excerpt,
            "temporary crop from mockup | source=mockupCrop | status=temporary | quality=bootstrap | risks=croppedFromScreenshot"
        )
    }

    /// Verifies fallback art facts at or above threshold do not produce findings.
    func testHighConfidenceFallbackArtProducesNoFinding() {
        let contract = ScreenAuditScreenContract(
            id: "hub",
            filename: "01_Hub.png",
            assets: ScreenAuditAssetExpectations(
                fallbackArt: [
                    ScreenAuditFallbackArtExpectation(
                        name: "quest-background",
                        confidence: 0.91,
                        minimumConfidence: 0.75
                    )
                ]
            )
        )
        let evidence = makeEvidence(transcript: "")

        let findings = ScreenAuditRuleEvaluator().evaluate(contract: contract, evidence: evidence)

        XCTAssertTrue(findings.isEmpty)
    }

    /// Creates a representative screen contract.
    /// - Parameter severityOverrides: Optional rule severity overrides.
    /// - Returns: Screen contract.
    private func makeContract(
        severityOverrides: [String: ScreenAuditSeverity] = [:]
    ) -> ScreenAuditScreenContract {
        ScreenAuditScreenContract(
            id: "hub",
            filename: "01_Hub.png",
            devices: [
                ScreenAuditDeviceExpectation(
                    label: "iPhone_large",
                    family: .iPhone,
                    pixelWidth: 1290,
                    pixelHeight: 2796,
                    orientation: .portrait
                )
            ],
            text: ScreenAuditTextExpectations(
                required: ["Quest Board", "Start"],
                forbidden: ["Debug"]
            ),
            role: .entry,
            pedagogyRole: .introduce,
            severityOverrides: severityOverrides
        )
    }

    /// Creates representative screenshot evidence.
    /// - Parameters:
    ///   - transcript: OCR transcript.
    ///   - pixelWidth: Screenshot width.
    ///   - pixelHeight: Screenshot height.
    /// - Returns: Screenshot evidence.
    private func makeEvidence(
        transcript: String,
        pixelWidth: Int = 1290,
        pixelHeight: Int = 2796
    ) -> ScreenAuditScreenshotEvidence {
        ScreenAuditScreenshotEvidence(
            screenID: "hub",
            path: "01_Hub.png",
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            hasAlpha: false,
            ocrTranscript: ScreenAuditOCRTranscript(fullText: transcript)
        )
    }
}
