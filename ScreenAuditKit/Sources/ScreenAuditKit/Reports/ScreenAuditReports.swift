import Foundation

/// Machine-readable evidence report written by CLI validation.
public struct ScreenAuditEvidenceReport: Codable, Equatable, Sendable {
    /// Report schema version.
    public let reportVersion: Int

    /// Project name from the decoded contract set.
    public let projectName: String

    /// Screenshot evidence collected during validation.
    public let screenshots: [ScreenAuditScreenshotEvidence]

    /// Creates an evidence report.
    /// - Parameters:
    ///   - reportVersion: Report schema version.
    ///   - projectName: Project name from the decoded contract set.
    ///   - screenshots: Screenshot evidence collected during validation.
    public init(
        reportVersion: Int = 1,
        projectName: String,
        screenshots: [ScreenAuditScreenshotEvidence]
    ) {
        self.reportVersion = reportVersion
        self.projectName = projectName
        self.screenshots = screenshots
    }
}

/// Machine-readable findings report written by CLI validation.
public struct ScreenAuditFindingsReport: Codable, Equatable, Sendable {
    /// Report schema version.
    public let reportVersion: Int

    /// Project name from the decoded contract set.
    public let projectName: String

    /// Deterministic findings produced by validation.
    public let findings: [ScreenAuditFinding]

    /// Creates a findings report.
    /// - Parameters:
    ///   - reportVersion: Report schema version.
    ///   - projectName: Project name from the decoded contract set.
    ///   - findings: Deterministic findings produced by validation.
    public init(
        reportVersion: Int = 1,
        projectName: String,
        findings: [ScreenAuditFinding]
    ) {
        self.reportVersion = reportVersion
        self.projectName = projectName
        self.findings = findings
    }

    /// Whether any finding is a hard CI failure.
    public var hasHardFailures: Bool {
        findings.contains { $0.severity == .error }
    }
}

/// Writes ScreenAuditKit reports in JSON and Markdown formats.
public struct ScreenAuditReportWriter {
    private let encoder: JSONEncoder

    /// Creates a report writer.
    /// - Parameter encoder: JSON encoder used for machine-readable reports.
    public init(encoder: JSONEncoder = ScreenAuditReportWriter.defaultEncoder()) {
        self.encoder = encoder
    }

    /// Returns the default JSON encoder for report output.
    /// - Returns: Configured JSON encoder.
    public static func defaultEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Writes evidence, findings, and Markdown reports to an output directory.
    /// - Parameters:
    ///   - evidenceReport: Evidence report.
    ///   - findingsReport: Findings report.
    ///   - flowReport: Optional flow report.
    ///   - outputDirectory: Directory where reports should be written.
    public func writeReports(
        evidenceReport: ScreenAuditEvidenceReport,
        findingsReport: ScreenAuditFindingsReport,
        flowReport: ScreenAuditFlowReport? = nil,
        outputDirectory: URL
    ) throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        try encoder.encode(evidenceReport).write(
            to: outputDirectory.appendingPathComponent("evidence.json"),
            options: .atomic
        )
        try encoder.encode(findingsReport).write(
            to: outputDirectory.appendingPathComponent("findings.json"),
            options: .atomic
        )
        let includeFlowDocs = flowReport.map { !$0.flows.isEmpty } ?? false
        try markdownSummary(for: findingsReport, includesFlowDocumentation: includeFlowDocs).write(
            to: outputDirectory.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )

        if let flowReport {
            try encoder.encode(flowReport).write(
                to: outputDirectory.appendingPathComponent("flow.json"),
                options: .atomic
            )
            try markdownFlowSummary(for: flowReport).write(
                to: outputDirectory.appendingPathComponent("flow-summary.md"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    /// Builds a Markdown summary for humans reviewing validation output.
    /// - Parameters:
    ///   - findingsReport: Findings to summarize.
    ///   - includesFlowDocumentation: When true, the triage section mentions `flow-summary.md`
    ///     because the contract declared at least one flow and flow reports were written.
    /// - Returns: Markdown summary text.
    public func markdownSummary(
        for findingsReport: ScreenAuditFindingsReport,
        includesFlowDocumentation: Bool = false
    ) -> String {
        let errorCount = findingsReport.findings.filter { $0.severity == .error }.count
        let warningCount = findingsReport.findings.filter { $0.severity == .warning }.count
        let infoCount = findingsReport.findings.filter { $0.severity == .info }.count

        var lines: [String] = [
            "# Screen Audit Summary",
            "",
            "- Project: \(findingsReport.projectName)",
            "- Findings: \(findingsReport.findings.count)",
            "- Hard failures (error): \(errorCount)",
            "- Warnings: \(warningCount)",
            "- Info: \(infoCount)",
            "",
            "## Where to look next",
            "",
            "- Annotated PNGs and per-screen explanations: `overlays/` (same directory as this file).",
        ]
        if includesFlowDocumentation {
            lines.append("- Ordered journey review: `flow-summary.md` (and machine-readable `flow.json`).")
        }
        lines.append("")

        if findingsReport.findings.isEmpty {
            lines.append("No findings.")
        } else {
            lines.append("## Review Queue")
            lines.append("")
            lines.append("| Severity | Rule | Screen | What failed | Why it matters | Suggested next step | Evidence |")
            lines.append("|---|---|---|---|---|---|---|")
            for finding in findingsReport.findings {
                lines.append(
                    "| \(finding.severity.rawValue) | \(finding.ruleID.rawValue) | \(finding.evidence.screenID) | \(markdownCell(finding.message)) | \(markdownCell(reviewImpact(for: finding.ruleID))) | \(markdownCell(recommendedAction(for: finding.ruleID))) | \(markdownCell(finding.evidence.excerpt)) |"
                )
            }

            lines.append("")
            lines.append("## Rule Guide")
            lines.append("")
            lines.append("| Rule | What ScreenAuditKit examined | Typical fix |")
            lines.append("|---|---|---|")

            for ruleID in orderedRuleIDs(in: findingsReport.findings) {
                lines.append("| \(ruleID.rawValue) | \(markdownCell(reviewImpact(for: ruleID))) | \(markdownCell(recommendedAction(for: ruleID))) |")
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Builds a Markdown summary for humans reviewing ordered screenshot flows.
    /// - Parameter flowReport: Flow report to summarize.
    /// - Returns: Markdown flow summary text.
    public func markdownFlowSummary(for flowReport: ScreenAuditFlowReport) -> String {
        var lines: [String] = [
            "# Screen Audit Flow Summary",
            "",
            "- Project: \(flowReport.projectName)",
            "- Flows: \(flowReport.flows.count)",
            "",
        ]

        if flowReport.flows.isEmpty {
            lines.append("No flows declared.")
            lines.append("")
            return lines.joined(separator: "\n")
        }

        for flow in flowReport.flows {
            lines.append("## \(flow.title)")
            lines.append("")
            lines.append("- Flow ID: \(flow.id)")
            lines.append("- Steps: \(flow.steps.count)")
            lines.append("")
            lines.append("| Step | Screen | Required | Status | Note |")
            lines.append("|---:|---|---|---|---|")

            for step in flow.steps {
                lines.append(
                    "| \(step.index + 1) | \(step.screenID) | \(step.required ? "yes" : "no") | \(step.status.rawValue) | \(step.note ?? "") |"
                )
            }

            lines.append("")
            lines.append("### Flow graph (advisory)")
            lines.append("")
            lines.append("```mermaid")
            lines.append("flowchart LR")
            var previousNode: String?
            for (index, step) in flow.steps.enumerated() {
                let nodeId = "n\(index)"
                let label = mermaidEscapeLabel(step.screenID)
                lines.append("    \(nodeId)[\"\(label)\"]")
                if let previousNode {
                    lines.append("    \(previousNode) --> \(nodeId)")
                }
                previousNode = nodeId
            }
            lines.append("```")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func mermaidEscapeLabel(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func orderedRuleIDs(in findings: [ScreenAuditFinding]) -> [ScreenAuditRuleID] {
        var seen: Set<ScreenAuditRuleID> = []
        var ruleIDs: [ScreenAuditRuleID] = []

        for finding in findings where !seen.contains(finding.ruleID) {
            seen.insert(finding.ruleID)
            ruleIDs.append(finding.ruleID)
        }

        return ruleIDs
    }

    private func reviewImpact(for ruleID: ScreenAuditRuleID) -> String {
        switch ruleID {
        case .missingScreenshot:
            return "A required screen did not produce a PNG, so docs, App Store assets, or flow validation may be stale."
        case .requiredTextMissing:
            return "Expected instructional or identifying copy was not detected in the screenshot evidence."
        case .forbiddenTextPresent:
            return "Debug, placeholder, or otherwise forbidden copy appears in the captured UI."
        case .textRulesSkipped:
            return "Text rules were declared, but this audit did not request OCR, so copy was not checked."
        case .dimensionMismatch:
            return "The PNG dimensions do not match any declared device expectation, which can invalidate visual comparisons."
        case .baselineDifferenceExceeded:
            return "The screenshot changed more than the allowed baseline threshold outside ignored regions."
        case .suspiciousOpaqueBorder:
            return "A transparent asset may have exported with an opaque rectangular matte around it."
        case .renderedMatteRisk:
            return "A critical visual region appears too flat or matte-like for authored art."
        case .checkerboardPatternRisk:
            return "A critical visual region resembles a checkerboard transparency artifact."
        case .lowConfidenceFallbackArt:
            return "A declared fallback or bootstrap asset is below the required confidence for shippable art."
        case .flowUnknownStep:
            return "A declared flow references a screen ID that is not present in the screen contract set."
        case .flowMissingRequiredStep:
            return "A required flow step has no screenshot evidence in this audit run."
        case .flowDuplicateStep:
            return "A flow repeats a screen ID, which may indicate a stuck state or duplicated documentation beat."
        case .flowPreviousStepMissing:
            return "A later flow step has a screenshot while an earlier required predecessor is missing, so the journey folder may be incomplete."
        }
    }

    private func recommendedAction(for ruleID: ScreenAuditRuleID) -> String {
        switch ruleID {
        case .missingScreenshot:
            return "Regenerate screenshots or update the contract only if the screen is intentionally removed."
        case .requiredTextMissing:
            return "Open the referenced PNG and confirm whether the copy is absent, clipped, localized differently, or missing from OCR."
        case .forbiddenTextPresent:
            return "Remove the forbidden copy from the UI or narrow the contract if it is intentionally visible."
        case .textRulesSkipped:
            return "Run the audit again with `--ocr vision` when text required/forbidden rules need enforcement."
        case .dimensionMismatch:
            return "Verify the screenshot folder came from the expected simulator family and update device expectations only for intentional changes."
        case .baselineDifferenceExceeded:
            return "Compare the overlay and baseline; accept a new baseline only after confirming the visual change is intentional."
        case .suspiciousOpaqueBorder:
            return "Inspect the source PNG alpha/export settings and re-ingest the asset if the matte is real."
        case .renderedMatteRisk:
            return "Inspect the highlighted critical region for missing art, flat placeholder rendering, or an incorrectly cropped asset."
        case .checkerboardPatternRisk:
            return "Inspect the highlighted critical region for checkerboard transparency showing through the final UI."
        case .lowConfidenceFallbackArt:
            return "Replace the fallback asset with approved authored art or raise confidence only with documented review."
        case .flowUnknownStep:
            return "Fix the flow screen ID or add the missing screen contract if the step is real."
        case .flowMissingRequiredStep:
            return "Regenerate the screenshot set or mark the step optional only if the flow no longer requires it."
        case .flowDuplicateStep:
            return "Confirm the repeated step is intentional; otherwise remove the duplicate from the flow contract."
        case .flowPreviousStepMissing:
            return "Regenerate the full flow screenshot set or clear `requirePreviousStepPresent` on the step if partial captures are expected."
        }
    }

    private func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "\\|")
    }
}
