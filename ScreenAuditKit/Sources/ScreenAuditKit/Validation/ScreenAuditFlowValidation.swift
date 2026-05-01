import Foundation

/// Machine-readable status for one flow step.
public enum ScreenAuditFlowStepStatus: String, Codable, Equatable, Sendable {
    /// The referenced screen is declared and has screenshot evidence in this run.
    case present

    /// The referenced screen is declared but has no screenshot evidence in this run.
    case missing

    /// The referenced screen ID is not declared by the contract set.
    case unknown
}

/// Validation status for one ordered flow step.
public struct ScreenAuditFlowStepResult: Codable, Equatable, Sendable {
    /// Zero-based step index in the flow.
    public let index: Int

    /// Screen contract ID expected at this point in the flow.
    public let screenID: String

    /// Whether this step is required by the flow contract.
    public let required: Bool

    /// Validation status for this step.
    public let status: ScreenAuditFlowStepStatus

    /// Optional project-specific note from the contract.
    public let note: String?

    /// Creates a flow step validation result.
    /// - Parameters:
    ///   - index: Zero-based step index in the flow.
    ///   - screenID: Screen contract ID expected at this point in the flow.
    ///   - required: Whether this step is required by the flow contract.
    ///   - status: Validation status for this step.
    ///   - note: Optional project-specific note from the contract.
    public init(
        index: Int,
        screenID: String,
        required: Bool,
        status: ScreenAuditFlowStepStatus,
        note: String? = nil
    ) {
        self.index = index
        self.screenID = screenID
        self.required = required
        self.status = status
        self.note = note
    }
}

/// Validation result for one ordered screenshot flow.
public struct ScreenAuditFlowResult: Codable, Equatable, Sendable {
    /// Stable flow identifier.
    public let id: String

    /// Human-readable flow title.
    public let title: String

    /// Ordered step results.
    public let steps: [ScreenAuditFlowStepResult]

    /// Creates a flow validation result.
    /// - Parameters:
    ///   - id: Stable flow identifier.
    ///   - title: Human-readable flow title.
    ///   - steps: Ordered step results.
    public init(id: String, title: String, steps: [ScreenAuditFlowStepResult]) {
        self.id = id
        self.title = title
        self.steps = steps
    }
}

/// Machine-readable flow report written by validation.
public struct ScreenAuditFlowReport: Codable, Equatable, Sendable {
    /// Report schema version.
    public let reportVersion: Int

    /// Project name from the decoded contract set.
    public let projectName: String

    /// Flow validation results.
    public let flows: [ScreenAuditFlowResult]

    /// Creates a flow report.
    /// - Parameters:
    ///   - reportVersion: Report schema version.
    ///   - projectName: Project name from the decoded contract set.
    ///   - flows: Flow validation results.
    public init(
        reportVersion: Int = 1,
        projectName: String,
        flows: [ScreenAuditFlowResult]
    ) {
        self.reportVersion = reportVersion
        self.projectName = projectName
        self.flows = flows
    }
}

/// Evaluates ordered screenshot flows against collected evidence.
public struct ScreenAuditFlowEvaluator {
    /// Creates a flow evaluator.
    public init() {}

    /// Evaluates declared flows against known screen contracts and collected evidence.
    /// - Parameters:
    ///   - contractSet: Decoded contract set.
    ///   - evidenceItems: Screenshot evidence collected during the current run.
    /// - Returns: Flow report and deterministic findings.
    public func evaluate(
        contractSet: ScreenAuditContractSet,
        evidenceItems: [ScreenAuditScreenshotEvidence]
    ) -> (report: ScreenAuditFlowReport, findings: [ScreenAuditFinding]) {
        let knownScreenIDs = Set(contractSet.screens.map(\.id))
        let observedScreenIDs = Set(evidenceItems.map(\.screenID))
        var findings: [ScreenAuditFinding] = []
        var flowResults: [ScreenAuditFlowResult] = []

        for flow in contractSet.flows {
            var seenScreenIDs: Set<String> = []
            var duplicateScreenIDs: Set<String> = []
            var stepResults: [ScreenAuditFlowStepResult] = []

            for (index, step) in flow.steps.enumerated() {
                let status: ScreenAuditFlowStepStatus
                if !knownScreenIDs.contains(step.screenID) {
                    status = .unknown
                    findings.append(unknownStepFinding(flow: flow, step: step, index: index))
                } else if observedScreenIDs.contains(step.screenID) {
                    status = .present
                } else {
                    status = .missing
                    if step.required {
                        findings.append(missingRequiredStepFinding(flow: flow, step: step, index: index))
                    }
                }

                if seenScreenIDs.contains(step.screenID), !duplicateScreenIDs.contains(step.screenID) {
                    duplicateScreenIDs.insert(step.screenID)
                    findings.append(duplicateStepFinding(flow: flow, step: step))
                }
                seenScreenIDs.insert(step.screenID)

                stepResults.append(
                    ScreenAuditFlowStepResult(
                        index: index,
                        screenID: step.screenID,
                        required: step.required,
                        status: status,
                        note: step.note
                    )
                )
            }

            flowResults.append(ScreenAuditFlowResult(id: flow.id, title: flow.title, steps: stepResults))
        }

        return (
            ScreenAuditFlowReport(projectName: contractSet.projectName, flows: flowResults),
            findings
        )
    }

    private func unknownStepFinding(
        flow: ScreenAuditFlowContract,
        step: ScreenAuditFlowStep,
        index: Int
    ) -> ScreenAuditFinding {
        ScreenAuditFinding(
            ruleID: .flowUnknownStep,
            severity: .error,
            confidence: 1.0,
            message: "Flow `\(flow.id)` step \(index + 1) references unknown screen `\(step.screenID)`.",
            evidence: ScreenAuditEvidenceReference(
                screenID: flow.id,
                path: flow.id,
                excerpt: step.screenID
            )
        )
    }

    private func missingRequiredStepFinding(
        flow: ScreenAuditFlowContract,
        step: ScreenAuditFlowStep,
        index: Int
    ) -> ScreenAuditFinding {
        ScreenAuditFinding(
            ruleID: .flowMissingRequiredStep,
            severity: .error,
            confidence: 1.0,
            message: "Flow `\(flow.id)` required step \(index + 1) screen `\(step.screenID)` has no screenshot evidence.",
            evidence: ScreenAuditEvidenceReference(
                screenID: step.screenID,
                path: flow.id,
                excerpt: "flow=\(flow.id), step=\(index + 1)"
            )
        )
    }

    private func duplicateStepFinding(
        flow: ScreenAuditFlowContract,
        step: ScreenAuditFlowStep
    ) -> ScreenAuditFinding {
        ScreenAuditFinding(
            ruleID: .flowDuplicateStep,
            severity: .warning,
            confidence: 1.0,
            message: "Flow `\(flow.id)` references screen `\(step.screenID)` more than once.",
            evidence: ScreenAuditEvidenceReference(
                screenID: step.screenID,
                path: flow.id,
                excerpt: "duplicate flow step"
            )
        )
    }
}
