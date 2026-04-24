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
    ///   - outputDirectory: Directory where reports should be written.
    public func writeReports(
        evidenceReport: ScreenAuditEvidenceReport,
        findingsReport: ScreenAuditFindingsReport,
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
        try markdownSummary(for: findingsReport).write(
            to: outputDirectory.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Builds a Markdown summary for humans reviewing validation output.
    /// - Parameter findingsReport: Findings to summarize.
    /// - Returns: Markdown summary text.
    public func markdownSummary(for findingsReport: ScreenAuditFindingsReport) -> String {
        var lines: [String] = [
            "# Screen Audit Summary",
            "",
            "- Project: \(findingsReport.projectName)",
            "- Findings: \(findingsReport.findings.count)",
            "- Hard failures: \(findingsReport.findings.filter { $0.severity == .error }.count)",
            "",
        ]

        if findingsReport.findings.isEmpty {
            lines.append("No findings.")
        } else {
            lines.append("| Severity | Rule | Screen | Evidence | Message |")
            lines.append("|---|---|---|---|---|")
            for finding in findingsReport.findings {
                lines.append(
                    "| \(finding.severity.rawValue) | \(finding.ruleID.rawValue) | \(finding.evidence.screenID) | \(finding.evidence.excerpt) | \(finding.message) |"
                )
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }
}
