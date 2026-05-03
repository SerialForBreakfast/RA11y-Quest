import CoreGraphics
import Foundation

/// A detected native Apple UI element in a screenshot.
public struct NativeUIElementObservation: Sendable, Identifiable, Codable {
    public let id: UUID

    /// Semantic role of the detected element (e.g. `primaryButton`, `navigationBar`).
    public let elementType: NativeUIElementType

    /// Bounding box in Vision's normalized coordinate system (bottom-left origin, [0,1] range).
    public let boundingBox: NativeUIRect

    /// Bounding box in screenshot pixel coordinates (top-left origin).
    public let boundingBoxPixels: NativeUIRect

    /// Detector confidence [0, 1].
    public let confidence: Double

    /// Visible text inside the element as returned by `VNRecognizeTextRequest`, if any.
    public let visibleText: String?

    /// Inferred accessibility traits (supplemental — not a substitute for the real accessibility tree).
    public let inferredTraits: [NativeUIAccessibilityTrait]

    /// Visual state of the element.
    public let state: NativeUIElementState

    /// Audit issues detected for this element (truncation, clipping, target size, etc.).
    public let issues: [NativeUIIssue]

    /// How the bounds and role were determined.
    public let confidenceSource: NativeUIConfidenceSource

    public init(
        id: UUID = UUID(),
        elementType: NativeUIElementType,
        boundingBox: NativeUIRect,
        boundingBoxPixels: NativeUIRect,
        confidence: Double,
        visibleText: String? = nil,
        inferredTraits: [NativeUIAccessibilityTrait] = [],
        state: NativeUIElementState = .init(),
        issues: [NativeUIIssue] = [],
        confidenceSource: NativeUIConfidenceSource
    ) {
        self.id = id
        self.elementType = elementType
        self.boundingBox = boundingBox
        self.boundingBoxPixels = boundingBoxPixels
        self.confidence = confidence
        self.visibleText = visibleText
        self.inferredTraits = inferredTraits
        self.state = state
        self.issues = issues
        self.confidenceSource = confidenceSource
    }
}

// MARK: - Element Type

/// Stable semantic role taxonomy for native Apple UI elements.
///
/// Roles are chosen for OS-version stability — they describe visual/semantic function,
/// not private UIKit/AppKit class names. Expanding this enum is a minor version bump;
/// renaming is a major version bump.
public enum NativeUIElementType: String, Codable, Sendable, CaseIterable {
    // Chrome
    case statusBar
    case navigationBar
    case tabBar
    case toolbar
    case sidebar
    case homeIndicator
    case dynamicIsland

    // Controls
    case primaryButton
    case secondaryButton
    case destructiveButton
    case cancelAction
    case textField
    case secureField
    case toggle
    case slider
    case segmentedControl
    case picker
    case stepperControl
    case searchField

    // Containers
    case alert
    case actionSheet
    case sheet
    case popover
    case listRow
    case collectionItem

    // Special
    case webContent
    case unknown
}

// MARK: - Accessibility Traits

/// Supplemental traits inferred from the screenshot.
///
/// These are probabilistic. For authoritative accessibility traits use the accessibility tree
/// from XCTest or the Accessibility Inspector — not screenshot inference.
public enum NativeUIAccessibilityTrait: String, Codable, Sendable {
    case button
    case link
    case header
    case image
    case selected
    case playsSound
    case keyboardKey
    case staticText
    case summaryElement
    case notEnabled
    case updatesFrequently
    case startsMediaSession
    case adjustable
    case allowsDirectInteraction
    case causesPageTurn
    case tabBar
}

// MARK: - Element State

/// Visible state of a detected UI element.
public struct NativeUIElementState: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var isSelected: Bool
    public var isFocused: Bool

    public init(isEnabled: Bool = true, isSelected: Bool = false, isFocused: Bool = false) {
        self.isEnabled = isEnabled
        self.isSelected = isSelected
        self.isFocused = isFocused
    }
}

// MARK: - Issues

/// An audit issue detected for a specific UI element observation.
public struct NativeUIIssue: Codable, Sendable {
    public let kind: NativeUIIssueKind
    public let description: String
    public let confidence: Double

    public init(kind: NativeUIIssueKind, description: String, confidence: Double) {
        self.kind = kind
        self.description = description
        self.confidence = confidence
    }
}

/// Categories of UI audit issues detectable from screenshots.
public enum NativeUIIssueKind: String, Codable, Sendable {
    case truncatedText
    case clippedElement
    case overlappingElements
    case tappableTargetTooSmall
    case contrastRisk
    case dynamicTypeOverflow
    case rtlMirroringFailure
    case missingLabel
    case offScreen
}

// MARK: - Confidence Source

/// How a `NativeUIElementObservation` was produced.
public enum NativeUIConfidenceSource: String, Codable, Sendable {
    /// Bounds and role came from a validated sidecar (hierarchy export). Highest accuracy.
    case sidecar
    /// Bounds and role came from CoreML pixel inference. Moderate accuracy.
    case pixelModel
    /// Derived from geometric/heuristic analysis (e.g. safe area inset rules). Lower accuracy.
    case heuristic
}

// MARK: - Device Inference

/// Probabilistic device and platform inference from screenshot pixels and metadata.
public struct NativeUIDeviceInference: Sendable, Codable {
    public let platform: NativeUIPlatform
    public let deviceCandidates: [NativeUIDeviceCandidate]
    public let inferredOSMajorVersion: Int?
    /// Overall confidence in the top device candidate [0, 1].
    public let confidence: Double

    public init(
        platform: NativeUIPlatform,
        deviceCandidates: [NativeUIDeviceCandidate],
        inferredOSMajorVersion: Int?,
        confidence: Double
    ) {
        self.platform = platform
        self.deviceCandidates = deviceCandidates
        self.inferredOSMajorVersion = inferredOSMajorVersion
        self.confidence = confidence
    }
}

public enum NativeUIPlatform: String, Codable, Sendable {
    case iOS
    case iPadOS
    case tvOS
    case macOS
    case visionOS
    case unknown
}

public struct NativeUIDeviceCandidate: Sendable, Codable {
    public let deviceFamily: String
    public let confidence: Double

    public init(deviceFamily: String, confidence: Double) {
        self.deviceFamily = deviceFamily
        self.confidence = confidence
    }
}
