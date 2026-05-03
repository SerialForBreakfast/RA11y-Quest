import XCTest
@testable import ScreenAuditKit

/// Tests ordered screenshot flow validation for ``ScreenAuditFlowEvaluator``.
///
/// Covers each branch in the evaluator (including `requirePreviousStepPresent` guards and
/// duplicate deduplication) so flow findings stay aligned with contract JSON and production
/// evidence sets.
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

    /// Verifies `requirePreviousStepPresent` emits a warning when a later step has evidence without its predecessor.
    func testRequirePreviousStepPresentProducesWarningWhenPredecessorMissing() throws {
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
                        ScreenAuditFlowStep(screenID: "ready", requirePreviousStepPresent: true)
                    ]
                )
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "ready")]
        )

        XCTAssertEqual(result.findings.count, 2)
        let ruleIDs = Set(result.findings.map(\.ruleID))
        XCTAssertTrue(ruleIDs.contains(.flowMissingRequiredStep))
        XCTAssertTrue(ruleIDs.contains(.flowPreviousStepMissing))
        XCTAssertTrue(result.findings.contains { $0.ruleID == .flowPreviousStepMissing && $0.severity == .warning })
    }

    /// Verifies when predecessor and current are both present, `requirePreviousStepPresent` does not emit a warning.
    func testRequirePreviousStepPresentWithPredecessorPresentProducesNoPreviousFinding() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png"),
                ScreenAuditScreenContract(id: "ready", filename: "02_Ready.png"),
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "linear",
                    title: "Linear",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "ready", requirePreviousStepPresent: true),
                    ]
                ),
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "entry"), makeEvidence(screenID: "ready")]
        )

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.report.flows.first?.steps.map(\.status), [.present, .present])
    }

    /// Verifies `requirePreviousStepPresent` on the first step never emits `flowPreviousStepMissing` (index guard).
    func testRequirePreviousStepPresentOnFirstStepOnlyNeverEmitsPreviousFinding() throws {
        let contractSet = try makeContractSet(
            screens: [ScreenAuditScreenContract(id: "solo", filename: "01_Solo.png")],
            flows: [
                ScreenAuditFlowContract(
                    id: "single",
                    title: "Single",
                    steps: [
                        ScreenAuditFlowStep(screenID: "solo", requirePreviousStepPresent: true),
                    ]
                ),
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "solo")]
        )

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.report.flows.first?.steps.map(\.status), [.present])
    }

    /// Verifies `requirePreviousStepPresent: false` does not add `flowPreviousStepMissing` when predecessor is absent.
    func testRequirePreviousStepPresentFalseDoesNotEmitPreviousFindingWhenPredecessorMissing() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png"),
                ScreenAuditScreenContract(id: "ready", filename: "02_Ready.png"),
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "linear",
                    title: "Linear",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "ready", required: true, requirePreviousStepPresent: false),
                    ]
                ),
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "ready")]
        )

        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.ruleID, .flowMissingRequiredStep)
        XCTAssertFalse(result.findings.contains { $0.ruleID == .flowPreviousStepMissing })
    }

    /// Verifies three repeated steps produce a single duplicate warning (deduped per screen ID).
    func testTripleDuplicateStepProducesSingleDuplicateFinding() throws {
        let contractSet = try makeContractSet(
            screens: [ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png")],
            flows: [
                ScreenAuditFlowContract(
                    id: "loop",
                    title: "Loop",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "entry"),
                    ]
                ),
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "entry")]
        )

        let duplicateFindings = result.findings.filter { $0.ruleID == .flowDuplicateStep }
        XCTAssertEqual(duplicateFindings.count, 1)
        XCTAssertEqual(result.findings.count, 1)
    }

    /// Verifies multiple flows are evaluated independently in one pass.
    func testTwoIndependentFlowsProduceSeparateReportsAndFindings() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "a", filename: "01_A.png"),
                ScreenAuditScreenContract(id: "b", filename: "02_B.png"),
                ScreenAuditScreenContract(id: "ghost", filename: "03_Ghost.png"),
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "okFlow",
                    title: "OK",
                    steps: [
                        ScreenAuditFlowStep(screenID: "a"),
                        ScreenAuditFlowStep(screenID: "b"),
                    ]
                ),
                ScreenAuditFlowContract(
                    id: "badFlow",
                    title: "Bad",
                    steps: [
                        ScreenAuditFlowStep(screenID: "ghost"),
                    ]
                ),
            ]
        )

        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [makeEvidence(screenID: "a"), makeEvidence(screenID: "b")]
        )

        XCTAssertEqual(result.report.flows.count, 2)
        XCTAssertEqual(result.report.flows.first?.id, "okFlow")
        XCTAssertEqual(result.report.flows.first?.steps.map(\.status), [.present, .present])
        XCTAssertEqual(result.report.flows.last?.id, "badFlow")
        XCTAssertEqual(result.report.flows.last?.steps.map(\.status), [.missing])

        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.ruleID, .flowMissingRequiredStep)
        XCTAssertEqual(result.findings.first?.evidence.screenID, "ghost")
    }

    /// Verifies duplicate evidence rows for the same `screenID` still satisfy presence (set semantics).
    func testDuplicateEvidenceScreenIDStillMarksStepPresent() throws {
        let contractSet = try makeContractSet(
            screens: [ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png")],
            flows: [
                ScreenAuditFlowContract(
                    id: "one",
                    title: "One",
                    steps: [ScreenAuditFlowStep(screenID: "entry")]
                ),
            ]
        )

        let dupA = makeEvidence(screenID: "entry")
        let dupB = makeEvidence(screenID: "entry")
        let result = ScreenAuditFlowEvaluator().evaluate(
            contractSet: contractSet,
            evidenceItems: [dupA, dupB]
        )

        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.report.flows.first?.steps.first?.status, .present)
    }

    /// Verifies evaluator output is deterministic for identical inputs (sorted finding projection).
    func testEvaluateIsDeterministicForIdenticalInputs() throws {
        let contractSet = try makeContractSet(
            screens: [
                ScreenAuditScreenContract(id: "entry", filename: "01_Entry.png"),
                ScreenAuditScreenContract(id: "ready", filename: "02_Ready.png"),
            ],
            flows: [
                ScreenAuditFlowContract(
                    id: "linear",
                    title: "Linear",
                    steps: [
                        ScreenAuditFlowStep(screenID: "entry"),
                        ScreenAuditFlowStep(screenID: "ready", requirePreviousStepPresent: true),
                    ]
                ),
            ]
        )
        let evidence = [makeEvidence(screenID: "ready")]
        let eval = ScreenAuditFlowEvaluator()

        let first = eval.evaluate(contractSet: contractSet, evidenceItems: evidence)
        let second = eval.evaluate(contractSet: contractSet, evidenceItems: evidence)

        let sigA = sortedFindingSignatures(first.findings)
        let sigB = sortedFindingSignatures(second.findings)
        XCTAssertEqual(sigA.count, sigB.count)
        for (lhs, rhs) in zip(sigA, sigB) {
            XCTAssertEqual(lhs.0, rhs.0)
            XCTAssertEqual(lhs.1, rhs.1)
            XCTAssertEqual(lhs.2, rhs.2)
        }
        XCTAssertEqual(first.report, second.report)
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

    /// Stable projection for comparing flow findings without relying on append order.
    private func sortedFindingSignatures(_ findings: [ScreenAuditFinding]) -> [(ScreenAuditRuleID, String, String)] {
        findings.map { finding in
            (
                finding.ruleID,
                finding.evidence.screenID,
                finding.evidence.excerpt
            )
        }
        .sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0.rawValue < rhs.0.rawValue }
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.2 < rhs.2
        }
    }
}
