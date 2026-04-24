import Foundation

/// Errors raised while decoding and validating screenshot contract files.
public enum ScreenAuditContractError: Error, Equatable, LocalizedError {
    /// The contract file declares a schema version this package cannot interpret.
    case unsupportedSchemaVersion(actual: Int, supported: Int)

    /// A required string field decoded as an empty or whitespace-only value.
    case emptyRequiredField(name: String)

    /// Human-readable error text suitable for CLI and report output.
    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(actual, supported):
            "Unsupported screen audit contract schema version \(actual). Supported version: \(supported)."
        case let .emptyRequiredField(name):
            "Screen audit contract field `\(name)` must not be empty."
        }
    }
}

/// Versioned collection of screen contracts decoded from JSON.
public struct ScreenAuditContractSet: Codable, Equatable, Sendable {
    /// Contract schema version supported by this package revision.
    public static let supportedSchemaVersion = 1

    /// Schema version declared by the contract file.
    public let schemaVersion: Int

    /// Human-readable project or contract collection name.
    public let projectName: String

    /// Screen-level contracts that define expected screenshot state.
    public let screens: [ScreenAuditScreenContract]

    /// Creates a contract set after validating schema and required fields.
    /// - Parameters:
    ///   - schemaVersion: Schema version declared by the contract file.
    ///   - projectName: Human-readable project or contract collection name.
    ///   - screens: Screen-level contracts.
    /// - Throws: `ScreenAuditContractError` when required contract metadata is invalid.
    public init(
        schemaVersion: Int,
        projectName: String,
        screens: [ScreenAuditScreenContract]
    ) throws {
        try Self.validateSchemaVersion(schemaVersion)
        try Self.validateRequired(projectName, name: "projectName")

        self.schemaVersion = schemaVersion
        self.projectName = projectName
        self.screens = screens
    }

    /// Decodes and validates a contract set from JSON data.
    /// - Parameters:
    ///   - data: JSON payload.
    ///   - decoder: JSON decoder to use.
    /// - Returns: Validated contract set.
    /// - Throws: Decoding or contract validation errors.
    public static func decode(
        from data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> ScreenAuditContractSet {
        let decoded = try decoder.decode(ScreenAuditContractSet.self, from: data)
        try validateSchemaVersion(decoded.schemaVersion)
        try validateRequired(decoded.projectName, name: "projectName")

        for screen in decoded.screens {
            try screen.validate()
        }

        return decoded
    }

    /// Validates a schema version before rule evaluation begins.
    /// - Parameter schemaVersion: Schema version declared by a contract file.
    /// - Throws: `ScreenAuditContractError.unsupportedSchemaVersion` for incompatible versions.
    public static func validateSchemaVersion(_ schemaVersion: Int) throws {
        guard schemaVersion == supportedSchemaVersion else {
            throw ScreenAuditContractError.unsupportedSchemaVersion(
                actual: schemaVersion,
                supported: supportedSchemaVersion
            )
        }
    }

    /// Validates a required string field.
    /// - Parameters:
    ///   - value: Value to inspect.
    ///   - name: Field name for diagnostics.
    /// - Throws: `ScreenAuditContractError.emptyRequiredField` when the value is empty.
    public static func validateRequired(_ value: String, name: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScreenAuditContractError.emptyRequiredField(name: name)
        }
    }
}

/// Contract for one expected screenshotable screen.
public struct ScreenAuditScreenContract: Codable, Equatable, Sendable {
    /// Stable screen identifier used in findings and reports.
    public let id: String

    /// Expected screenshot file name or project-defined filename pattern.
    public let filename: String

    /// Device expectations that must hold when a screenshot is validated.
    public let devices: [ScreenAuditDeviceExpectation]

    /// Expected and forbidden OCR text anchors.
    public let text: ScreenAuditTextExpectations

    /// Optional screen role used by flow and pedagogy validators.
    public let role: ScreenAuditScreenRole?

    /// Optional pedagogy role used by instructional-copy validators.
    public let pedagogyRole: ScreenAuditPedagogyRole?

    /// Rule-level severity overrides for this screen.
    public let severityOverrides: [String: ScreenAuditSeverity]

    /// Creates a screen contract.
    /// - Parameters:
    ///   - id: Stable screen identifier.
    ///   - filename: Expected screenshot file name or pattern.
    ///   - devices: Device expectations.
    ///   - text: OCR text expectations.
    ///   - role: Optional screen role.
    ///   - pedagogyRole: Optional pedagogy role.
    ///   - severityOverrides: Rule-level severity overrides.
    public init(
        id: String,
        filename: String,
        devices: [ScreenAuditDeviceExpectation] = [],
        text: ScreenAuditTextExpectations = ScreenAuditTextExpectations(),
        role: ScreenAuditScreenRole? = nil,
        pedagogyRole: ScreenAuditPedagogyRole? = nil,
        severityOverrides: [String: ScreenAuditSeverity] = [:]
    ) {
        self.id = id
        self.filename = filename
        self.devices = devices
        self.text = text
        self.role = role
        self.pedagogyRole = pedagogyRole
        self.severityOverrides = severityOverrides
    }

    /// Validates required screen metadata after decoding.
    /// - Throws: `ScreenAuditContractError` when required values are empty.
    public func validate() throws {
        try ScreenAuditContractSet.validateRequired(id, name: "screens[].id")
        try ScreenAuditContractSet.validateRequired(filename, name: "screens[].filename")
    }
}

/// Expected device metadata for a screen capture.
public struct ScreenAuditDeviceExpectation: Codable, Equatable, Sendable {
    /// Project-defined label for the device or device class.
    public let label: String

    /// Expected device family, when the contract needs family-specific checks.
    public let family: ScreenAuditDeviceFamily?

    /// Expected pixel width, when exact dimensions are known.
    public let pixelWidth: Int?

    /// Expected pixel height, when exact dimensions are known.
    public let pixelHeight: Int?

    /// Expected orientation.
    public let orientation: ScreenAuditOrientation?

    /// Creates a device expectation.
    /// - Parameters:
    ///   - label: Project-defined label for the device or device class.
    ///   - family: Optional device family.
    ///   - pixelWidth: Optional expected pixel width.
    ///   - pixelHeight: Optional expected pixel height.
    ///   - orientation: Optional expected orientation.
    public init(
        label: String,
        family: ScreenAuditDeviceFamily? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        orientation: ScreenAuditOrientation? = nil
    ) {
        self.label = label
        self.family = family
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.orientation = orientation
    }
}

/// OCR text expectations for a screen.
public struct ScreenAuditTextExpectations: Codable, Equatable, Sendable {
    /// Text anchors that must appear in OCR evidence.
    public let required: [String]

    /// Text anchors that may appear and can be surfaced in reports.
    public let optional: [String]

    /// Text anchors that must not appear in OCR evidence.
    public let forbidden: [String]

    /// Creates text expectations.
    /// - Parameters:
    ///   - required: Text anchors that must appear.
    ///   - optional: Text anchors that may appear.
    ///   - forbidden: Text anchors that must not appear.
    public init(
        required: [String] = [],
        optional: [String] = [],
        forbidden: [String] = []
    ) {
        self.required = required
        self.optional = optional
        self.forbidden = forbidden
    }
}

/// Broad device family for family-specific expectations.
public enum ScreenAuditDeviceFamily: String, Codable, Equatable, Sendable {
    /// iPhone-class screenshots.
    case iPhone

    /// iPad-class screenshots.
    case iPad

    /// macOS screenshots.
    case mac

    /// tvOS screenshots.
    case tv

    /// visionOS screenshots.
    case vision
}

/// Screenshot orientation expectation.
public enum ScreenAuditOrientation: String, Codable, Equatable, Sendable {
    /// Height is greater than width.
    case portrait

    /// Width is greater than height.
    case landscape
}

/// Generic screen role for state and flow reporting.
public enum ScreenAuditScreenRole: String, Codable, Equatable, Sendable {
    /// Initial or landing screen.
    case entry

    /// Tutorial or instructional screen.
    case tutorial

    /// Active interaction or gameplay screen.
    case play

    /// Successful completion state.
    case success

    /// Failed completion state.
    case failure

    /// Summary or result state.
    case result
}

/// Generic pedagogy role for ordered instructional copy.
public enum ScreenAuditPedagogyRole: String, Codable, Equatable, Sendable {
    /// Introduces the skill or concept.
    case introduce

    /// Repeats or strengthens the introduced concept.
    case reinforce

    /// Gives the user supported practice.
    case practice

    /// Tests the user with less scaffolding.
    case test

    /// Concludes or reflects on the learned skill.
    case conclude
}

/// Severity levels used by contracts, rules, and reports.
public enum ScreenAuditSeverity: String, Codable, Equatable, Sendable {
    /// Informational note.
    case info

    /// Advisory issue that should not fail CI by default.
    case warning

    /// Deterministic issue that should fail CI.
    case error
}
