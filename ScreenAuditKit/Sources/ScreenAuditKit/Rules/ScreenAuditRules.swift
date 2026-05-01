import Foundation

/// Rule identifiers emitted by deterministic validation.
public enum ScreenAuditRuleID: String, Codable, Equatable, Sendable {
    /// A screenshot file declared by a contract was not found.
    case missingScreenshot

    /// A required OCR text anchor was missing from screenshot evidence.
    case requiredTextMissing

    /// A forbidden OCR text anchor was present in screenshot evidence.
    case forbiddenTextPresent

    /// Screenshot dimensions did not match a device expectation.
    case dimensionMismatch

    /// Screenshot pixels differed from the configured baseline beyond the allowed threshold.
    case baselineDifferenceExceeded

    /// PNG transparency appears to have a rectangular opaque border around transparent content.
    case suspiciousOpaqueBorder

    /// Rendered screenshot region appears to contain a large flat matte block.
    case renderedMatteRisk

    /// Rendered screenshot region appears to contain a checkerboard-like transparency artifact.
    case checkerboardPatternRisk

    /// Project-supplied fallback art confidence is below the configured threshold.
    case lowConfidenceFallbackArt

    /// A flow references a screen ID that is not declared in the screen contract set.
    case flowUnknownStep

    /// A required flow step does not have screenshot evidence in the current run.
    case flowMissingRequiredStep

    /// A flow references the same screen more than once, which may indicate a stuck or duplicated state.
    case flowDuplicateStep
}

/// Reference to the source evidence that produced a finding.
public struct ScreenAuditEvidenceReference: Codable, Equatable, Sendable {
    /// Stable screen identifier.
    public let screenID: String

    /// Screenshot path associated with the finding.
    public let path: String

    /// Human-readable evidence excerpt.
    public let excerpt: String

    /// Creates an evidence reference.
    /// - Parameters:
    ///   - screenID: Stable screen identifier.
    ///   - path: Screenshot path associated with the finding.
    ///   - excerpt: Human-readable evidence excerpt.
    public init(screenID: String, path: String, excerpt: String) {
        self.screenID = screenID
        self.path = path
        self.excerpt = excerpt
    }
}

/// Deterministic rule finding produced by validation.
public struct ScreenAuditFinding: Codable, Equatable, Sendable {
    /// Rule that produced the finding.
    public let ruleID: ScreenAuditRuleID

    /// Finding severity after applying contract overrides.
    public let severity: ScreenAuditSeverity

    /// Confidence from 0.0 to 1.0.
    public let confidence: Double

    /// Human-readable finding message.
    public let message: String

    /// Source evidence reference.
    public let evidence: ScreenAuditEvidenceReference

    /// Creates a deterministic rule finding.
    /// - Parameters:
    ///   - ruleID: Rule that produced the finding.
    ///   - severity: Finding severity after applying contract overrides.
    ///   - confidence: Confidence from 0.0 to 1.0.
    ///   - message: Human-readable finding message.
    ///   - evidence: Source evidence reference.
    public init(
        ruleID: ScreenAuditRuleID,
        severity: ScreenAuditSeverity,
        confidence: Double,
        message: String,
        evidence: ScreenAuditEvidenceReference
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.confidence = confidence
        self.message = message
        self.evidence = evidence
    }
}

/// Evaluates deterministic rules against one screen contract and screenshot evidence.
public struct ScreenAuditRuleEvaluator {
    /// Creates a rule evaluator.
    public init() {}

    /// Evaluates currently supported deterministic rules.
    /// - Parameters:
    ///   - contract: Screen contract to evaluate.
    ///   - evidence: Screenshot evidence for the same screen.
    /// - Returns: Findings produced by supported rules.
    public func evaluate(
        contract: ScreenAuditScreenContract,
        evidence: ScreenAuditScreenshotEvidence,
        provenanceSet: ScreenAuditAssetProvenanceSet? = nil
    ) -> [ScreenAuditFinding] {
        var findings: [ScreenAuditFinding] = []
        findings.append(contentsOf: evaluateRequiredText(contract: contract, evidence: evidence))
        findings.append(contentsOf: evaluateForbiddenText(contract: contract, evidence: evidence))
        findings.append(contentsOf: evaluateDimensions(contract: contract, evidence: evidence))
        findings.append(contentsOf: evaluateFallbackArt(contract: contract, evidence: evidence, provenanceSet: provenanceSet))
        return findings
    }

    private func evaluateRequiredText(
        contract: ScreenAuditScreenContract,
        evidence: ScreenAuditScreenshotEvidence
    ) -> [ScreenAuditFinding] {
        contract.text.required.compactMap { requiredText in
            guard !containsText(requiredText, in: evidence.ocrTranscript.fullText) else {
                return nil
            }

            return ScreenAuditFinding(
                ruleID: .requiredTextMissing,
                severity: severity(for: .requiredTextMissing, contract: contract, defaultSeverity: .error),
                confidence: 1.0,
                message: "Required text `\(requiredText)` was not found.",
                evidence: ScreenAuditEvidenceReference(
                    screenID: evidence.screenID,
                    path: evidence.path,
                    excerpt: evidence.ocrTranscript.fullText
                )
            )
        }
    }

    private func evaluateForbiddenText(
        contract: ScreenAuditScreenContract,
        evidence: ScreenAuditScreenshotEvidence
    ) -> [ScreenAuditFinding] {
        contract.text.forbidden.compactMap { forbiddenText in
            guard containsText(forbiddenText, in: evidence.ocrTranscript.fullText) else {
                return nil
            }

            return ScreenAuditFinding(
                ruleID: .forbiddenTextPresent,
                severity: severity(for: .forbiddenTextPresent, contract: contract, defaultSeverity: .error),
                confidence: 1.0,
                message: "Forbidden text `\(forbiddenText)` was found.",
                evidence: ScreenAuditEvidenceReference(
                    screenID: evidence.screenID,
                    path: evidence.path,
                    excerpt: forbiddenText
                )
            )
        }
    }

    private func evaluateDimensions(
        contract: ScreenAuditScreenContract,
        evidence: ScreenAuditScreenshotEvidence
    ) -> [ScreenAuditFinding] {
        guard !contract.devices.isEmpty else {
            return []
        }

        let matchesAnyExpectation = contract.devices.contains { device in
            let widthMatches = device.pixelWidth.map { $0 == evidence.pixelWidth } ?? true
            let heightMatches = device.pixelHeight.map { $0 == evidence.pixelHeight } ?? true
            return widthMatches && heightMatches
        }

        guard !matchesAnyExpectation else {
            return []
        }

        let expectedSummary = contract.devices
            .map { device in
                let expectedWidth = device.pixelWidth.map(String.init) ?? "*"
                let expectedHeight = device.pixelHeight.map(String.init) ?? "*"
                return "`\(device.label)` \(expectedWidth)x\(expectedHeight)"
            }
            .joined(separator: ", ")

        return [
            ScreenAuditFinding(
                ruleID: .dimensionMismatch,
                severity: severity(for: .dimensionMismatch, contract: contract, defaultSeverity: .error),
                confidence: 1.0,
                message: "Screenshot dimensions were \(evidence.pixelWidth)x\(evidence.pixelHeight); expected one of: \(expectedSummary).",
                evidence: ScreenAuditEvidenceReference(
                    screenID: evidence.screenID,
                    path: evidence.path,
                    excerpt: "\(evidence.pixelWidth)x\(evidence.pixelHeight)"
                )
            )
        ]
    }

    private func evaluateFallbackArt(
        contract: ScreenAuditScreenContract,
        evidence: ScreenAuditScreenshotEvidence,
        provenanceSet: ScreenAuditAssetProvenanceSet?
    ) -> [ScreenAuditFinding] {
        var findings: [ScreenAuditFinding] = []

        for fallbackArt in contract.assets.fallbackArt {
            guard fallbackArt.confidence < fallbackArt.minimumConfidence else {
                continue
            }

            let confidence = formattedRatio(fallbackArt.confidence)
            let minimum = formattedRatio(fallbackArt.minimumConfidence)
            let provenance = provenanceSet.flatMap {
                $0.asset(id: fallbackArt.provenanceID ?? fallbackArt.name)
            }
            let messageSuffix: String
            if let provenance {
                messageSuffix = " Provenance: \(provenanceDescription(provenance))."
            } else {
                messageSuffix = ""
            }

            findings.append(ScreenAuditFinding(
                ruleID: .lowConfidenceFallbackArt,
                severity: severity(for: .lowConfidenceFallbackArt, contract: contract, defaultSeverity: .warning),
                confidence: max(0, min(1, 1 - fallbackArt.confidence)),
                message: "Fallback art `\(fallbackArt.name)` confidence \(confidence) is below the required \(minimum).\(messageSuffix)",
                evidence: ScreenAuditEvidenceReference(
                    screenID: evidence.screenID,
                    path: evidence.path,
                    excerpt: fallbackEvidence(fallbackArt: fallbackArt, provenance: provenance)
                )
            ))
        }

        return findings
    }

    private func containsText(_ needle: String, in haystack: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func formattedRatio(_ ratio: Double) -> String {
        String(format: "%.2f", ratio)
    }

    private func provenanceDescription(_ provenance: ScreenAuditAssetProvenance) -> String {
        "\(provenance.source.rawValue), \(provenance.authoringStatus.rawValue), \(provenance.sourceQuality.rawValue)"
    }

    private func fallbackEvidence(
        fallbackArt: ScreenAuditFallbackArtExpectation,
        provenance: ScreenAuditAssetProvenance?
    ) -> String {
        var parts: [String] = []
        if let note = fallbackArt.note {
            parts.append(note)
        }
        if let provenance {
            parts.append("source=\(provenance.source.rawValue)")
            parts.append("status=\(provenance.authoringStatus.rawValue)")
            parts.append("quality=\(provenance.sourceQuality.rawValue)")
            if !provenance.knownRisks.isEmpty {
                let risks = provenance.knownRisks.joined(separator: ", ")
                parts.append("risks=\(risks)")
            }
            if !provenance.evidence.isEmpty {
                let evidence = provenance.evidence.joined(separator: ", ")
                parts.append("evidence=\(evidence)")
            }
            if let note = provenance.note {
                parts.append(note)
            }
        }
        return parts.isEmpty ? "Project-supplied fallback art confidence" : parts.joined(separator: " | ")
    }

    private func severity(
        for ruleID: ScreenAuditRuleID,
        contract: ScreenAuditScreenContract,
        defaultSeverity: ScreenAuditSeverity
    ) -> ScreenAuditSeverity {
        contract.severityOverrides[ruleID.rawValue] ?? defaultSeverity
    }
}
