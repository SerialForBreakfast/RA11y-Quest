import XCTest
@testable import ScreenAuditKit

/// Tests ordered screenshot flow validation.
final class ScreenAuditFlowTests: XCTestCase {
    /// Verifies present flow steps produce a report without findings.
    func testCompleteFlowProducesNoFindings() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png"),
                ScreenAuditScreenContract(id: "ready", filename: "02_Ready.png")
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "firstSpell",
                    title: "First Spell",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "ready")
                    ]
                )
            ]
        )
        let evidence = [
            makeEvidence(screenID: "entry"),
            makeEvidence(screenID: "ready")
        ]

        let result = ScreenAuditFlowEvaluator().evaluate(contractSet: contractSet, evidenceItems: evidence)

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.report.flows.first?.steps.map(\.status), [.present, .present])
    }

    /// Verifies required missing flow steps are hard failures.
    func testMissingRequiredFlowStepProducesFinding() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png"),
                ScreenAuditScreenContract(id: "ready", filename: "02_Ready.png")
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "firstSpell",
                    title: "First Spell",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "ready")
                    ]
                )
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "entry")]
        )

        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.ruleID, .flowMissingRequiredStep)
        XCTAssertEqual(result.findings.first?.severity, .error)
        XCTAssertEqual(result.findings.first?.evidence.screenID, "ready")
        XCTAssertEqual(result.report.flows.first?.steps.map(\.status), [.present, .missing])
    }

    /// Verifies optional missing flow steps remain report-only.
    func testMissingOptionalFlowStepDoesNotProduceFinding() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png"),
                ScreenAuditScreenContract(id: "help", filename: "02_Help.png")
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "firstSpell",
                    title: "First Spell",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "help", required: false)
                    ]
                )
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "entry")]
        )

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.report.flows.first?.steps.map(\.status), [.present, .missing])
    }

    /// Verifies duplicate flow steps are warnings for reviewer attention.
    func testDuplicateFlowStepProducesWarning() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png")
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "stuckFlow",
                    title: "Stuck Flow",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "entry")
                    ]
                )
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "entry")]
        )

        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.ruleID, .flowDuplicateStep)
        XCTAssertEqual(result.findings.first?.severity, .warning)
    }

    /// Verifies unknown flow screen references are hard failures.
    func testUnknownFlowStepProducesFinding() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png")
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "brokenFlow",
                    title: "Broken Flow",
                    steps: [
                        ScreenAuditFlowStep(screenID: "missingScreen")
                    ]
                )
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "entry")]
        )

        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.ruleID, .flowUnknownStep)
        XCTAssertEqual(result.findings.first?.severity, .error)
        XCTAssertEqual(result.report.flows.first?.steps.first?.status, .unknown)
    }

    private func makeContractSet(
        screens: [ScreenAuditScreenContract],
        flows: [ScreenAuditFlowContract]
    ) throws -> ScreenAuditContractSet {
        try ScreenAuditContractSet(
            schemaVersion: 1,
            projectName: "Flow Fixture",
            screens: screens,
            flows: flows
        )
    }

    private func makeEvidence(screenID: String) -> ScreenAuditScreenshotEvidence {
        ScreenAuditScreenshotEvidence(
            screenID: screenID,
            path: "\(screenID).png",
            pixelWidth: 1,
            pixelHeight: 1,
            hasAlpha: false,
            ocrTranscript: ScreenAuditOCRTranscript(fullText: "")
        )
    }
}
