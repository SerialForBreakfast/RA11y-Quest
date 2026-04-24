import Foundation

/// Errors raised by validation orchestration.
public enum ScreenAuditValidationError: Error, Equatable, LocalizedError {
    /// Required command input was missing.
    case missingInput(path: String)

    /// A required path exists but has the wrong file-system kind.
    case invalidInput(path: String, expected: String)

    /// Report files could not be written.
    case reportWriteFailed(path: String)

    /// Human-readable error text suitable for CLI output.
    public var errorDescription: String? {
        switch self {
        case let .missingInput(path):
            "Required input does not exist: `\(path)`."
        case let .invalidInput(path, expected):
            "Invalid input at `\(path)`. Expected \(expected)."
        case let .reportWriteFailed(path):
            "Unable to write screen audit reports to `\(path)`."
        }
    }
}

/// Result of a validation run.
public struct ScreenAuditValidationResult: Equatable, Sendable {
    /// Evidence report produced by validation.
    public let evidenceReport: ScreenAuditEvidenceReport

    /// Findings report produced by validation.
    public let findingsReport: ScreenAuditFindingsReport

    /// Creates a validation result.
    /// - Parameters:
    ///   - evidenceReport: Evidence report produced by validation.
    ///   - findingsReport: Findings report produced by validation.
    public init(
        evidenceReport: ScreenAuditEvidenceReport,
        findingsReport: ScreenAuditFindingsReport
    ) {
        self.evidenceReport = evidenceReport
        self.findingsReport = findingsReport
    }
}

/// Runs deterministic screenshot validation from filesystem inputs.
public struct ScreenAuditValidator {
    private let imageExtractor: ScreenAuditImageEvidenceExtractor
    private let ruleEvaluator: ScreenAuditRuleEvaluator
    private let reportWriter: ScreenAuditReportWriter
    private let baselineComparator: ScreenAuditBaselineComparator

    /// Creates a filesystem validator.
    /// - Parameters:
    ///   - imageExtractor: Extracts screenshot evidence.
    ///   - ruleEvaluator: Evaluates deterministic rules.
    ///   - reportWriter: Writes validation reports.
    public init(
        imageExtractor: ScreenAuditImageEvidenceExtractor = ScreenAuditImageEvidenceExtractor(),
        ruleEvaluator: ScreenAuditRuleEvaluator = ScreenAuditRuleEvaluator(),
        reportWriter: ScreenAuditReportWriter = ScreenAuditReportWriter(),
        baselineComparator: ScreenAuditBaselineComparator = ScreenAuditBaselineComparator()
    ) {
        self.imageExtractor = imageExtractor
        self.ruleEvaluator = ruleEvaluator
        self.reportWriter = reportWriter
        self.baselineComparator = baselineComparator
    }

    /// Validates screenshots against a contract file and writes reports.
    /// - Parameters:
    ///   - screenshotsDirectory: Directory containing screenshot PNGs.
    ///   - contractFile: JSON contract file.
    ///   - outputDirectory: Directory where reports should be written.
    /// - Returns: Validation result.
    public func validate(
        screenshotsDirectory: URL,
        contractFile: URL,
        outputDirectory: URL,
        baselineDirectory: URL? = nil
    ) throws -> ScreenAuditValidationResult {
        try validateExistingDirectory(screenshotsDirectory)
        try validateExistingFile(contractFile)
        if let baselineDirectory {
            try validateExistingDirectory(baselineDirectory)
        }

        let contractData: Data
        do {
            contractData = try Data(contentsOf: contractFile)
        } catch {
            throw ScreenAuditValidationError.missingInput(path: contractFile.path)
        }

        let contractSet = try ScreenAuditContractSet.decode(from: contractData)
        var evidenceItems: [ScreenAuditScreenshotEvidence] = []
        var findings: [ScreenAuditFinding] = []

        for screen in contractSet.screens {
            let screenshotURL = screenshotsDirectory.appendingPathComponent(screen.filename)
            guard FileManager.default.fileExists(atPath: screenshotURL.path) else {
                findings.append(missingScreenshotFinding(screen: screen, path: screenshotURL.path))
                continue
            }

            let evidence = try imageExtractor.extractPNG(at: screenshotURL, screenID: screen.id)
            evidenceItems.append(evidence)
            findings.append(contentsOf: ruleEvaluator.evaluate(contract: screen, evidence: evidence))
            if let baseline = screen.baseline, let baselineDirectory {
                let baselineURL = baselineDirectory.appendingPathComponent(baseline.referencePath)
                let diff = try baselineComparator.compare(
                    screenshotURL: screenshotURL,
                    baselineURL: baselineURL,
                    ignoredRegions: screen.regions.ignored
                )
                if let finding = baselineComparator.findingIfNeeded(
                    diff: diff,
                    contract: screen,
                    evidence: evidence
                ) {
                    findings.append(finding)
                }
            }
        }

        let evidenceReport = ScreenAuditEvidenceReport(
            projectName: contractSet.projectName,
            screenshots: evidenceItems
        )
        let findingsReport = ScreenAuditFindingsReport(
            projectName: contractSet.projectName,
            findings: findings
        )

        do {
            try reportWriter.writeReports(
                evidenceReport: evidenceReport,
                findingsReport: findingsReport,
                outputDirectory: outputDirectory
            )
        } catch {
            throw ScreenAuditValidationError.reportWriteFailed(path: outputDirectory.path)
        }

        return ScreenAuditValidationResult(
            evidenceReport: evidenceReport,
            findingsReport: findingsReport
        )
    }

    private func validateExistingDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ScreenAuditValidationError.missingInput(path: url.path)
        }
        guard isDirectory.boolValue else {
            throw ScreenAuditValidationError.invalidInput(path: url.path, expected: "directory")
        }
    }

    private func validateExistingFile(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ScreenAuditValidationError.missingInput(path: url.path)
        }
        guard !isDirectory.boolValue else {
            throw ScreenAuditValidationError.invalidInput(path: url.path, expected: "file")
        }
    }

    private func missingScreenshotFinding(
        screen: ScreenAuditScreenContract,
        path: String
    ) -> ScreenAuditFinding {
        ScreenAuditFinding(
            ruleID: .missingScreenshot,
            severity: screen.severityOverrides[ScreenAuditRuleID.missingScreenshot.rawValue] ?? .error,
            confidence: 1.0,
            message: "Expected screenshot `\(screen.filename)` was not found.",
            evidence: ScreenAuditEvidenceReference(
                screenID: screen.id,
                path: path,
                excerpt: screen.filename
            )
        )
    }
}
