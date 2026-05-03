import CoreGraphics
import Foundation

/// Configuration for a `NativeUIDetectionRequest`.
///
/// Future options will include model version selection, confidence thresholds,
/// element class filtering, and sidecar validation policy.
public struct NativeUIDetectionConfiguration: Sendable {
    /// Minimum detector confidence to include an observation in results.
    public var minimumConfidence: Double

    /// Whether to run `VNRecognizeTextRequest` and associate text to detected elements.
    public var includesTextRecognition: Bool

    public init(minimumConfidence: Double = 0.5, includesTextRecognition: Bool = true) {
        self.minimumConfidence = minimumConfidence
        self.includesTextRecognition = includesTextRecognition
    }

    public static let `default` = NativeUIDetectionConfiguration()
}

/// Detects visible native Apple UI elements from a screenshot image.
///
/// Styled after Vision's request pattern. Instances are immutable after initialization
/// and may be created from any concurrency context. `perform(on:sidecar:)` runs
/// Vision and CoreML inference off the main actor — callers should not invoke it
/// on the main actor without wrapping in a `Task`.
///
/// ## Two operating modes
///
/// **Sidecar mode** (`sidecar != nil`): the caller supplies a `NativeUISidecar` exported
/// from the same test run that produced the PNG. Bounds and roles come from the hierarchy;
/// the pixel model acts as a cross-check. Highest confidence.
///
/// **Pixel-only mode** (`sidecar == nil`): runs `VNCoreMLRequest` on raw pixels. Useful
/// for orphan PNGs that have no accompanying hierarchy export. Moderate confidence; wider
/// tolerances recommended in contracts.
///
/// - Note: Not functional until the `NativeUIAuditKitModels` package provides a `.mlpackage`.
public struct NativeUIDetectionRequest: Sendable {
    public let configuration: NativeUIDetectionConfiguration

    public init(configuration: NativeUIDetectionConfiguration = .default) {
        self.configuration = configuration
    }

    /// Runs detection on the supplied screenshot.
    ///
    /// - Parameters:
    ///   - screenshot: The screenshot to analyze.
    ///   - sidecar: Optional hierarchy metadata from the same capture run.
    /// - Returns: Detected UI element observations ordered by descending confidence.
    /// - Throws: `NativeUIDetectionError.modelUnavailable` until the model package ships.
    public func perform(
        on screenshot: CGImage,
        sidecar: NativeUISidecar? = nil
    ) async throws -> [NativeUIElementObservation] {
        throw NativeUIDetectionError.modelUnavailable
    }
}

/// Errors produced by `NativeUIDetectionRequest`.
public enum NativeUIDetectionError: Error, Sendable, Equatable {
    /// The CoreML model package has not been installed. Add `NativeUIAuditKitModels` as a dependency.
    case modelUnavailable
    /// The supplied image could not be decoded or resized for inference.
    case imagePreprocessingFailed
    /// The model produced an output shape that this runtime version cannot decode.
    case unexpectedModelOutput(String)
}

/// Hierarchy metadata exported from the same test run that produced a PNG.
///
/// When present, sidecar data gives NativeUIDetectionRequest ground-truth bounds
/// and semantic roles without relying solely on pixel inference.
///
/// Schema version must match `NativeUISidecar.currentSchemaVersion` or decoding will throw.
public struct NativeUISidecar: Codable, Sendable {
    public static let currentSchemaVersion = "1.0"

    public let schemaVersion: String
    public let imageSHA256: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let scale: Double
    public let platform: String
    public let osVersion: String
    public let deviceName: String
    public let colorScheme: String
    public let dynamicTypeSize: String
    public let locale: String
    public let elements: [NativeUISidecarElement]

    public init(
        schemaVersion: String = currentSchemaVersion,
        imageSHA256: String,
        pixelWidth: Int,
        pixelHeight: Int,
        scale: Double,
        platform: String,
        osVersion: String,
        deviceName: String,
        colorScheme: String,
        dynamicTypeSize: String,
        locale: String,
        elements: [NativeUISidecarElement]
    ) {
        self.schemaVersion = schemaVersion
        self.imageSHA256 = imageSHA256
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
        self.platform = platform
        self.osVersion = osVersion
        self.deviceName = deviceName
        self.colorScheme = colorScheme
        self.dynamicTypeSize = dynamicTypeSize
        self.locale = locale
        self.elements = elements
    }
}

/// A single element entry in a `NativeUISidecar`.
public struct NativeUISidecarElement: Codable, Sendable {
    public let id: String
    public let elementType: String
    public let framework: String
    public let boundsPixels: NativeUIRect
    public let boundsPoints: NativeUIRect
    public let boundsVisionNormalized: NativeUIRect
    public let visibleText: String?
    public let accessibilityLabel: String?
    public let traits: [String]
    public let knownIssues: [String]

    public init(
        id: String,
        elementType: String,
        framework: String,
        boundsPixels: NativeUIRect,
        boundsPoints: NativeUIRect,
        boundsVisionNormalized: NativeUIRect,
        visibleText: String? = nil,
        accessibilityLabel: String? = nil,
        traits: [String] = [],
        knownIssues: [String] = []
    ) {
        self.id = id
        self.elementType = elementType
        self.framework = framework
        self.boundsPixels = boundsPixels
        self.boundsPoints = boundsPoints
        self.boundsVisionNormalized = boundsVisionNormalized
        self.visibleText = visibleText
        self.accessibilityLabel = accessibilityLabel
        self.traits = traits
        self.knownIssues = knownIssues
    }
}

/// A serializable rectangle used in sidecar and report JSON.
///
/// Coordinate origin depends on context (see property docs on containing types).
public struct NativeUIRect: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
