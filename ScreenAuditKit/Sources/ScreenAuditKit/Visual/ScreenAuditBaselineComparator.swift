import CoreGraphics
import Foundation
import ImageIO

/// Errors raised while comparing screenshots to baselines.
public enum ScreenAuditBaselineError: Error, Equatable, LocalizedError {
    /// Baseline image could not be read from disk.
    case unreadableBaseline(path: String)

    /// The screenshot and baseline dimensions differ.
    case dimensionMismatch(actual: String, baseline: String)

    /// Image pixels could not be decoded for comparison.
    case pixelDecodeFailed(path: String)

    /// Human-readable error text suitable for CLI output.
    public var errorDescription: String? {
        switch self {
        case let .unreadableBaseline(path):
            "Unable to read baseline image at `\(path)`."
        case let .dimensionMismatch(actual, baseline):
            "Screenshot dimensions \(actual) do not match baseline dimensions \(baseline)."
        case let .pixelDecodeFailed(path):
            "Unable to decode pixels for baseline comparison: `\(path)`."
        }
    }
}

/// Pixel-diff metric produced by baseline comparison.
public struct ScreenAuditBaselineDiff: Codable, Equatable, Sendable {
    /// Number of pixels included after ignored regions are removed.
    public let comparedPixels: Int

    /// Number of compared pixels that differed.
    public let mismatchedPixels: Int

    /// Ratio of mismatched pixels to compared pixels.
    public let mismatchRatio: Double

    /// Creates a baseline diff result.
    /// - Parameters:
    ///   - comparedPixels: Number of pixels included after ignored regions are removed.
    ///   - mismatchedPixels: Number of compared pixels that differed.
    ///   - mismatchRatio: Ratio of mismatched pixels to compared pixels.
    public init(comparedPixels: Int, mismatchedPixels: Int, mismatchRatio: Double) {
        self.comparedPixels = comparedPixels
        self.mismatchedPixels = mismatchedPixels
        self.mismatchRatio = mismatchRatio
    }
}

/// Compares PNG screenshots to PNG baselines using deterministic pixel metrics.
public struct ScreenAuditBaselineComparator {
    /// Creates a baseline comparator.
    public init() {}

    /// Compares two PNG files while ignoring configured regions.
    /// - Parameters:
    ///   - screenshotURL: Screenshot PNG URL.
    ///   - baselineURL: Baseline PNG URL.
    ///   - ignoredRegions: Regions to remove from comparison.
    /// - Returns: Pixel-diff metric.
    public func compare(
        screenshotURL: URL,
        baselineURL: URL,
        ignoredRegions: [ScreenAuditRegion]
    ) throws -> ScreenAuditBaselineDiff {
        guard FileManager.default.fileExists(atPath: baselineURL.path) else {
            throw ScreenAuditBaselineError.unreadableBaseline(path: baselineURL.path)
        }

        let actual = try RGBAImage(url: screenshotURL)
        let baseline = try RGBAImage(url: baselineURL)

        guard actual.width == baseline.width, actual.height == baseline.height else {
            throw ScreenAuditBaselineError.dimensionMismatch(
                actual: "\(actual.width)x\(actual.height)",
                baseline: "\(baseline.width)x\(baseline.height)"
            )
        }

        var comparedPixels = 0
        var mismatchedPixels = 0

        for y in 0..<actual.height {
            for x in 0..<actual.width {
                guard !ignoredRegions.containsPixel(x: x, y: y) else {
                    continue
                }

                comparedPixels += 1
                let offset = ((y * actual.width) + x) * 4
                if actual.bytes[offset] != baseline.bytes[offset]
                    || actual.bytes[offset + 1] != baseline.bytes[offset + 1]
                    || actual.bytes[offset + 2] != baseline.bytes[offset + 2]
                    || actual.bytes[offset + 3] != baseline.bytes[offset + 3] {
                    mismatchedPixels += 1
                }
            }
        }

        let mismatchRatio = comparedPixels == 0 ? 0 : Double(mismatchedPixels) / Double(comparedPixels)
        return ScreenAuditBaselineDiff(
            comparedPixels: comparedPixels,
            mismatchedPixels: mismatchedPixels,
            mismatchRatio: mismatchRatio
        )
    }

    /// Creates a finding when a baseline diff exceeds the configured threshold.
    /// - Parameters:
    ///   - diff: Baseline diff metric.
    ///   - contract: Screen contract.
    ///   - evidence: Screenshot evidence.
    /// - Returns: Finding when threshold is exceeded.
    public func findingIfNeeded(
        diff: ScreenAuditBaselineDiff,
        contract: ScreenAuditScreenContract,
        evidence: ScreenAuditScreenshotEvidence
    ) -> ScreenAuditFinding? {
        guard let baseline = contract.baseline else {
            return nil
        }

        guard diff.mismatchRatio > baseline.maxMismatchRatio else {
            return nil
        }

        return ScreenAuditFinding(
            ruleID: .baselineDifferenceExceeded,
            severity: contract.severityOverrides[ScreenAuditRuleID.baselineDifferenceExceeded.rawValue] ?? .warning,
            confidence: 1.0,
            message: "Baseline mismatch ratio \(String(format: "%.4f", diff.mismatchRatio)) exceeded allowed ratio \(String(format: "%.4f", baseline.maxMismatchRatio)).",
            evidence: ScreenAuditEvidenceReference(
                screenID: evidence.screenID,
                path: evidence.path,
                excerpt: "\(diff.mismatchedPixels)/\(diff.comparedPixels) pixels"
            )
        )
    }
}

private struct RGBAImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(url: URL) throws {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenAuditBaselineError.pixelDecodeFailed(path: url.path)
        }

        width = image.width
        height = image.height

        var mutableBytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &mutableBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenAuditBaselineError.pixelDecodeFailed(path: url.path)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = mutableBytes
    }
}

private extension Array where Element == ScreenAuditRegion {
    func containsPixel(x: Int, y: Int) -> Bool {
        contains { region in
            x >= region.x
                && y >= region.y
                && x < region.x + region.width
                && y < region.y + region.height
        }
    }
}
