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

    /// Flow report produced by validation.
    public let flowReport: ScreenAuditFlowReport

    /// Overlay PNG paths produced by validation.
    public let overlayPaths: [String]

    /// Creates a validation result.
    /// - Parameters:
    ///   - evidenceReport: Evidence report produced by validation.
    ///   - findingsReport: Findings report produced by validation.
    ///   - flowReport: Flow report produced by validation.
    ///   - overlayPaths: Overlay PNG paths produced by validation.
    public init(
        evidenceReport: ScreenAuditEvidenceReport,
        findingsReport: ScreenAuditFindingsReport,
        flowReport: ScreenAuditFlowReport,
        overlayPaths: [String] = []
    ) {
        self.evidenceReport = evidenceReport
        self.findingsReport = findingsReport
        self.flowReport = flowReport
        self.overlayPaths = overlayPaths
    }
}

/// Runs deterministic screenshot validation from filesystem inputs.
public struct ScreenAuditValidator {
    private let imageExtractor: ScreenAuditImageEvidenceExtractor
    private let ruleEvaluator: ScreenAuditRuleEvaluator
    private let reportWriter: ScreenAuditReportWriter
    private let baselineComparator: ScreenAuditBaselineComparator
    private let overlayRenderer: ScreenAuditOverlayRenderer
    private let renderedMatteInspector: ScreenAuditRenderedMatteInspector
    private let checkerboardInspector: ScreenAuditCheckerboardInspector
    private let flowEvaluator: ScreenAuditFlowEvaluator

    /// Creates a filesystem validator.
    /// - Parameters:
    ///   - imageExtractor: Extracts screenshot evidence.
    ///   - ruleEvaluator: Evaluates deterministic rules.
    ///   - reportWriter: Writes validation reports.
    ///   - baselineComparator: Compares screenshots against optional baselines.
    ///   - overlayRenderer: Renders failed-region review overlays.
    ///   - renderedMatteInspector: Inspects critical regions for matte-like artifacts.
    ///   - checkerboardInspector: Inspects critical regions for checkerboard-like artifacts.
    ///   - flowEvaluator: Evaluates ordered screenshot flows.
    public init(
        imageExtractor: ScreenAuditImageEvidenceExtractor = ScreenAuditImageEvidenceExtractor(),
        ruleEvaluator: ScreenAuditRuleEvaluator = ScreenAuditRuleEvaluator(),
        reportWriter: ScreenAuditReportWriter = ScreenAuditReportWriter(),
        baselineComparator: ScreenAuditBaselineComparator = ScreenAuditBaselineComparator(),
        overlayRenderer: ScreenAuditOverlayRenderer = ScreenAuditOverlayRenderer(),
        renderedMatteInspector: ScreenAuditRenderedMatteInspector = ScreenAuditRenderedMatteInspector(),
        checkerboardInspector: ScreenAuditCheckerboardInspector = ScreenAuditCheckerboardInspector(),
        flowEvaluator: ScreenAuditFlowEvaluator = ScreenAuditFlowEvaluator()
    ) {
        self.imageExtractor = imageExtractor
        self.ruleEvaluator = ruleEvaluator
        self.reportWriter = reportWriter
        self.baselineComparator = baselineComparator
        self.overlayRenderer = overlayRenderer
        self.renderedMatteInspector = renderedMatteInspector
        self.checkerboardInspector = checkerboardInspector
        self.flowEvaluator = flowEvaluator
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
        let provenanceSet = try loadProvenanceSet(
            path: contractSet.assetProvenancePath,
            contractFile: contractFile
        )
        var evidenceItems: [ScreenAuditScreenshotEvidence] = []
        var findings: [ScreenAuditFinding] = []
        var overlayInputs: [ScreenAuditOverlayInput] = []

        for screen in contractSet.screens {
            let screenshotURL = screenshotsDirectory.appendingPathComponent(screen.filename)
            guard FileManager.default.fileExists(atPath: screenshotURL.path) else {
                findings.append(missingScreenshotFinding(screen: screen, path: screenshotURL.path))
                continue
            }

            let evidence = try imageExtractor.extractPNG(at: screenshotURL, screenID: screen.id)
            evidenceItems.append(evidence)
            let screenFindingStartIndex = findings.count
            findings.append(contentsOf: ruleEvaluator.evaluate(contract: screen, evidence: evidence, provenanceSet: provenanceSet))
            findings.append(
                contentsOf: try evaluateCriticalVisualRules(
                    screen: screen,
                    screenshotURL: screenshotURL,
                    evidence: evidence
                )
            )
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
            if findings.count > screenFindingStartIndex {
                let screenFindings = Array(findings[screenFindingStartIndex..<findings.count])
                overlayInputs.append(
                    ScreenAuditOverlayInput(
                        screen: screen,
                        screenshotURL: screenshotURL,
                        pixelWidth: evidence.pixelWidth,
                        pixelHeight: evidence.pixelHeight,
                        findings: screenFindings
                    )
                )
            }
        }

        let evidenceReport = ScreenAuditEvidenceReport(
            projectName: contractSet.projectName,
            screenshots: evidenceItems
        )
        let flowEvaluation = flowEvaluator.evaluate(
            contractSet: contractSet,
            evidenceItems: evidenceItems
        )
        findings.append(contentsOf: flowEvaluation.findings)
        let findingsReport = ScreenAuditFindingsReport(
            projectName: contractSet.projectName,
            findings: findings
        )

        do {
            try reportWriter.writeReports(
                evidenceReport: evidenceReport,
                findingsReport: findingsReport,
                flowReport: flowEvaluation.report,
                outputDirectory: outputDirectory
            )
        } catch {
            throw ScreenAuditValidationError.reportWriteFailed(path: outputDirectory.path)
        }

        let overlayPaths: [String]
        do {
            overlayPaths = try writeOverlays(
                inputs: overlayInputs,
                outputDirectory: outputDirectory.appendingPathComponent("overlays")
            )
        } catch {
            throw ScreenAuditValidationError.reportWriteFailed(path: outputDirectory.appendingPathComponent("overlays").path)
        }

        return ScreenAuditValidationResult(
            evidenceReport: evidenceReport,
            findingsReport: findingsReport,
            flowReport: flowEvaluation.report,
            overlayPaths: overlayPaths
        )
    }

    private func loadProvenanceSet(
        path: String?,
        contractFile: URL
    ) throws -> ScreenAuditAssetProvenanceSet? {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let provenanceURL = contractFile.deletingLastPathComponent().appendingPathComponent(path)
        try validateExistingFile(provenanceURL)
        let data = try Data(contentsOf: provenanceURL)
        return try JSONDecoder().decode(ScreenAuditAssetProvenanceSet.self, from: data)
    }

    private func writeOverlays(
        inputs: [ScreenAuditOverlayInput],
        outputDirectory: URL
    ) throws -> [String] {
        var paths: [String] = []
        let encoder = ScreenAuditReportWriter.defaultEncoder()

        for input in inputs {
            let outputURL = outputDirectory.appendingPathComponent("\(sanitizedFilename(input.screen.id))-overlay.png")
            let regions = overlayRegions(for: input)
            try overlayRenderer.render(
                screenshotURL: input.screenshotURL,
                regions: regions,
                outputURL: outputURL
            )
            let report = ScreenAuditOverlayReport(
                screenID: input.screen.id,
                screenshotPath: input.screenshotURL.path,
                overlayPath: outputURL.path,
                findings: input.findings,
                regions: regions
            )
            try encoder.encode(report).write(
                to: outputURL.deletingPathExtension().appendingPathExtension("json"),
                options: .atomic
            )
            try overlayMarkdown(for: report).write(
                to: outputURL.deletingPathExtension().appendingPathExtension("md"),
                atomically: true,
                encoding: .utf8
            )
            paths.append(outputURL.path)
        }

        return paths
    }

    private func evaluateCriticalVisualRules(
        screen: ScreenAuditScreenContract,
        screenshotURL: URL,
        evidence: ScreenAuditScreenshotEvidence
    ) throws -> [ScreenAuditFinding] {
        var visualFindings: [ScreenAuditFinding] = []

        for region in screen.regions.critical {
            let scaledRegion = region.scaled(toPixelWidth: evidence.pixelWidth, pixelHeight: evidence.pixelHeight)
            let matteInspection = try renderedMatteInspector.inspect(
                screenshotURL: screenshotURL,
                region: scaledRegion
            )
            if let matteFinding = renderedMatteInspector.findingIfNeeded(
                inspection: matteInspection,
                screenID: screen.id,
                path: screenshotURL.path,
                severity: screen.severityOverrides[ScreenAuditRuleID.renderedMatteRisk.rawValue] ?? .warning
            ) {
                visualFindings.append(matteFinding)
            }

            let checkerboardInspection = try checkerboardInspector.inspect(
                screenshotURL: screenshotURL,
                region: scaledRegion
            )
            if let checkerboardFinding = checkerboardInspector.findingIfNeeded(
                inspection: checkerboardInspection,
                screenID: screen.id,
                path: screenshotURL.path,
                severity: screen.severityOverrides[ScreenAuditRuleID.checkerboardPatternRisk.rawValue] ?? .warning
            ) {
                visualFindings.append(checkerboardFinding)
            }
        }

        return visualFindings
    }

    private func overlayRegions(for input: ScreenAuditOverlayInput) -> [ScreenAuditOverlayRegion] {
        var regions: [ScreenAuditOverlayRegion] = []
        regions.append(contentsOf: input.screen.regions.ignored.map { ScreenAuditOverlayRegion(region: scaled($0, input: input), role: .ignored) })
        regions.append(contentsOf: input.screen.regions.protected.map { ScreenAuditOverlayRegion(region: scaled($0, input: input), role: .protected) })
        regions.append(contentsOf: input.screen.regions.critical.map { ScreenAuditOverlayRegion(region: scaled($0, input: input), role: .critical) })

        if regions.isEmpty {
            regions.append(
                ScreenAuditOverlayRegion(
                    region: ScreenAuditRegion(
                        name: "screenshot",
                        x: 0,
                        y: 0,
                        width: input.pixelWidth,
                        height: input.pixelHeight
                    ),
                    role: .screenshot
                )
            )
        }

        return regions
    }

    private func scaled(_ region: ScreenAuditRegion, input: ScreenAuditOverlayInput) -> ScreenAuditRegion {
        region.scaled(toPixelWidth: input.pixelWidth, pixelHeight: input.pixelHeight)
    }

    private func overlayMarkdown(for report: ScreenAuditOverlayReport) -> String {
        var lines: [String] = [
            "# Screen Audit Overlay",
            "",
            "- Screen: \(report.screenID)",
            "- Screenshot: \(report.screenshotPath)",
            "- Overlay: \(report.overlayPath)",
            "",
            "## Findings",
            "",
        ]

        for finding in report.findings {
            lines.append("- \(finding.severity.rawValue) \(finding.ruleID.rawValue): \(finding.message)")
            lines.append("  Evidence: \(finding.evidence.excerpt)")
        }

        lines.append("")
        lines.append("## Regions")
        lines.append("")

        for region in report.regions {
            lines.append("- \(region.role.rawValue) \(region.region.name): x \(region.region.x), y \(region.region.y), width \(region.region.width), height \(region.region.height)")
        }

        lines.append("")
        lines.append("Legend: red = critical or failure review region, blue = protected region, amber = ignored region.")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars)
        return sanitized.isEmpty ? "screen" : sanitized
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

private struct ScreenAuditOverlayInput {
    let screen: ScreenAuditScreenContract
    let screenshotURL: URL
    let pixelWidth: Int
    let pixelHeight: Int
    let findings: [ScreenAuditFinding]
}
