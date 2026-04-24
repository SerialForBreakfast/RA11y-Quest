import CoreGraphics
import Foundation
import ImageIO

/// Errors raised while inspecting screenshot regions for checkerboard-like patterns.
public enum ScreenAuditCheckerboardError: Error, Equatable, LocalizedError {
    /// The screenshot pixels could not be decoded.
    case pixelDecodeFailed(path: String)

    /// Human-readable error text suitable for CLI output.
    public var errorDescription: String? {
        switch self {
        case let .pixelDecodeFailed(path):
            "Unable to decode pixels for checkerboard inspection: `\(path)`."
        }
    }
}

/// Metrics for alternating checkerboard-like cells inside a screenshot region.
public struct ScreenAuditCheckerboardInspection: Codable, Equatable, Sendable {
    /// Region inspected.
    public let region: ScreenAuditRegion

    /// Width and height of each inspected cell in pixels.
    public let cellSize: Int

    /// Number of cells available for pattern analysis.
    public let inspectedCellCount: Int

    /// Number of neighboring 2x2 cell groups checked.
    public let checkedBlockCount: Int

    /// Number of checked 2x2 groups that match the checkerboard heuristic.
    public let alternatingBlockCount: Int

    /// Ratio of alternating groups to checked groups.
    public let alternatingRatio: Double

    /// Whether the region meets the checkerboard risk heuristic.
    public let isRisk: Bool

    /// Creates checkerboard inspection metrics.
    /// - Parameters:
    ///   - region: Region inspected.
    ///   - cellSize: Width and height of each inspected cell in pixels.
    ///   - inspectedCellCount: Number of cells available for pattern analysis.
    ///   - checkedBlockCount: Number of neighboring 2x2 cell groups checked.
    ///   - alternatingBlockCount: Number of checked 2x2 groups that match the checkerboard heuristic.
    ///   - alternatingRatio: Ratio of alternating groups to checked groups.
    ///   - isRisk: Whether the region meets the checkerboard risk heuristic.
    public init(
        region: ScreenAuditRegion,
        cellSize: Int,
        inspectedCellCount: Int,
        checkedBlockCount: Int,
        alternatingBlockCount: Int,
        alternatingRatio: Double,
        isRisk: Bool
    ) {
        self.region = region
        self.cellSize = cellSize
        self.inspectedCellCount = inspectedCellCount
        self.checkedBlockCount = checkedBlockCount
        self.alternatingBlockCount = alternatingBlockCount
        self.alternatingRatio = alternatingRatio
        self.isRisk = isRisk
    }
}

/// Inspects screenshot regions for transparency checkerboard artifacts.
public struct ScreenAuditCheckerboardInspector {
    /// Creates a checkerboard inspector.
    public init() {}

    /// Inspects a screenshot region for alternating checkerboard-like cells.
    /// - Parameters:
    ///   - url: Screenshot PNG URL.
    ///   - region: Region to inspect.
    ///   - cellSize: Width and height of each inspected cell in pixels.
    ///   - minimumAlternatingRatio: Minimum alternating 2x2 coverage required to flag the region.
    ///   - maximumSameColorDistance: Maximum channel distance for colors expected to match diagonally.
    ///   - minimumDifferentColorDistance: Minimum channel distance for colors expected to differ orthogonally.
    /// - Returns: Checkerboard inspection metrics.
    public func inspect(
        screenshotURL url: URL,
        region: ScreenAuditRegion,
        cellSize: Int = 8,
        minimumAlternatingRatio: Double = 0.8,
        maximumSameColorDistance: Int = 10,
        minimumDifferentColorDistance: Int = 24
    ) throws -> ScreenAuditCheckerboardInspection {
        let image = try CheckerboardInspectableImage(url: url)
        let boundedRegion = region.clamped(toWidth: image.width, height: image.height)
        let normalizedCellSize = max(1, cellSize)
        let columns = boundedRegion.width / normalizedCellSize
        let rows = boundedRegion.height / normalizedCellSize
        let inspectedCellCount = columns * rows

        guard columns >= 2, rows >= 2 else {
            return ScreenAuditCheckerboardInspection(
                region: boundedRegion,
                cellSize: normalizedCellSize,
                inspectedCellCount: inspectedCellCount,
                checkedBlockCount: 0,
                alternatingBlockCount: 0,
                alternatingRatio: 0,
                isRisk: false
            )
        }

        let cells = cellColors(
            image: image,
            region: boundedRegion,
            cellSize: normalizedCellSize,
            columns: columns,
            rows: rows
        )

        var checkedBlockCount = 0
        var alternatingBlockCount = 0

        for row in 0..<(rows - 1) {
            for column in 0..<(columns - 1) {
                checkedBlockCount += 1
                let topLeft = cells[(row * columns) + column]
                let topRight = cells[(row * columns) + column + 1]
                let bottomLeft = cells[((row + 1) * columns) + column]
                let bottomRight = cells[((row + 1) * columns) + column + 1]

                if topLeft.distance(to: bottomRight) <= maximumSameColorDistance,
                   topRight.distance(to: bottomLeft) <= maximumSameColorDistance,
                   topLeft.distance(to: topRight) >= minimumDifferentColorDistance,
                   topLeft.distance(to: bottomLeft) >= minimumDifferentColorDistance {
                    alternatingBlockCount += 1
                }
            }
        }

        let alternatingRatio = checkedBlockCount == 0 ? 0 : Double(alternatingBlockCount) / Double(checkedBlockCount)
        let isRisk = alternatingRatio >= minimumAlternatingRatio

        return ScreenAuditCheckerboardInspection(
            region: boundedRegion,
            cellSize: normalizedCellSize,
            inspectedCellCount: inspectedCellCount,
            checkedBlockCount: checkedBlockCount,
            alternatingBlockCount: alternatingBlockCount,
            alternatingRatio: alternatingRatio,
            isRisk: isRisk
        )
    }

    /// Builds a finding when inspection metrics indicate a checkerboard artifact.
    /// - Parameters:
    ///   - inspection: Checkerboard inspection metrics.
    ///   - screenID: Screen identifier.
    ///   - path: Screenshot path.
    ///   - severity: Finding severity.
    /// - Returns: Finding when the region is risky.
    public func findingIfNeeded(
        inspection: ScreenAuditCheckerboardInspection,
        screenID: String,
        path: String,
        severity: ScreenAuditSeverity = .warning
    ) -> ScreenAuditFinding? {
        guard inspection.isRisk else {
            return nil
        }

        return ScreenAuditFinding(
            ruleID: .checkerboardPatternRisk,
            severity: severity,
            confidence: 0.75,
            message: "Region `\(inspection.region.name)` contains an alternating checkerboard-like pattern that may indicate a rendered transparency artifact.",
            evidence: ScreenAuditEvidenceReference(
                screenID: screenID,
                path: path,
                excerpt: "\(inspection.alternatingBlockCount)/\(inspection.checkedBlockCount) alternating cell groups"
            )
        )
    }

    private func cellColors(
        image: CheckerboardInspectableImage,
        region: ScreenAuditRegion,
        cellSize: Int,
        columns: Int,
        rows: Int
    ) -> [CheckerboardColor] {
        var colors: [CheckerboardColor] = []
        colors.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for column in 0..<columns {
                colors.append(
                    image.averageColor(
                        x: region.x + (column * cellSize),
                        y: region.y + (row * cellSize),
                        width: cellSize,
                        height: cellSize
                    )
                )
            }
        }

        return colors
    }
}

private struct CheckerboardInspectableImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(url: URL) throws {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenAuditCheckerboardError.pixelDecodeFailed(path: url.path)
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
            throw ScreenAuditCheckerboardError.pixelDecodeFailed(path: url.path)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = mutableBytes
    }

    func averageColor(x: Int, y: Int, width: Int, height: Int) -> CheckerboardColor {
        var red = 0
        var green = 0
        var blue = 0
        var count = 0

        for sampleY in y..<(y + height) {
            for sampleX in x..<(x + width) {
                let offset = ((sampleY * self.width) + sampleX) * 4
                red += Int(bytes[offset])
                green += Int(bytes[offset + 1])
                blue += Int(bytes[offset + 2])
                count += 1
            }
        }

        return CheckerboardColor(
            red: red / count,
            green: green / count,
            blue: blue / count
        )
    }
}

private struct CheckerboardColor {
    let red: Int
    let green: Int
    let blue: Int

    func distance(to other: CheckerboardColor) -> Int {
        abs(red - other.red) + abs(green - other.green) + abs(blue - other.blue)
    }
}

private extension ScreenAuditRegion {
    func clamped(toWidth imageWidth: Int, height imageHeight: Int) -> ScreenAuditRegion {
        let clampedX = max(0, min(x, imageWidth))
        let clampedY = max(0, min(y, imageHeight))
        let maxWidth = max(0, imageWidth - clampedX)
        let maxHeight = max(0, imageHeight - clampedY)
        return ScreenAuditRegion(
            name: name,
            x: clampedX,
            y: clampedY,
            width: max(0, min(width, maxWidth)),
            height: max(0, min(height, maxHeight))
        )
    }
}
