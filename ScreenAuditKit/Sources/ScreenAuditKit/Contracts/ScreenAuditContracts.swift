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

    /// Region definitions used by visual rules.
    public let regions: ScreenAuditRegionSet

    /// Optional baseline comparison expectation.
    public let baseline: ScreenAuditBaselineExpectation?

    /// Optional asset quality facts supplied by a project-specific pipeline.
    public let assets: ScreenAuditAssetExpectations

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
    ///   - regions: Region definitions used by visual rules.
    ///   - baseline: Optional baseline comparison expectation.
    ///   - assets: Optional asset quality facts supplied by a project-specific pipeline.
    ///   - severityOverrides: Rule-level severity overrides.
    public init(
        id: String,
        filename: String,
        devices: [ScreenAuditDeviceExpectation] = [],
        text: ScreenAuditTextExpectations = ScreenAuditTextExpectations(),
        role: ScreenAuditScreenRole? = nil,
        pedagogyRole: ScreenAuditPedagogyRole? = nil,
        regions: ScreenAuditRegionSet = ScreenAuditRegionSet(),
        baseline: ScreenAuditBaselineExpectation? = nil,
        assets: ScreenAuditAssetExpectations = ScreenAuditAssetExpectations(),
        severityOverrides: [String: ScreenAuditSeverity] = [:]
    ) {
        self.id = id
        self.filename = filename
        self.devices = devices
        self.text = text
        self.role = role
        self.pedagogyRole = pedagogyRole
        self.regions = regions
        self.baseline = baseline
        self.assets = assets
        self.severityOverrides = severityOverrides
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case filename
        case devices
        case text
        case role
        case pedagogyRole
        case regions
        case baseline
        case assets
        case severityOverrides
    }

    /// Decodes a screen contract, defaulting newly added optional sections for old fixtures.
    /// - Parameter decoder: Source decoder.
    /// - Throws: Decoding errors.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        devices = try container.decodeIfPresent([ScreenAuditDeviceExpectation].self, forKey: .devices) ?? []
        text = try container.decodeIfPresent(ScreenAuditTextExpectations.self, forKey: .text) ?? ScreenAuditTextExpectations()
        role = try container.decodeIfPresent(ScreenAuditScreenRole.self, forKey: .role)
        pedagogyRole = try container.decodeIfPresent(ScreenAuditPedagogyRole.self, forKey: .pedagogyRole)
        regions = try container.decodeIfPresent(ScreenAuditRegionSet.self, forKey: .regions) ?? ScreenAuditRegionSet()
        baseline = try container.decodeIfPresent(ScreenAuditBaselineExpectation.self, forKey: .baseline)
        assets = try container.decodeIfPresent(ScreenAuditAssetExpectations.self, forKey: .assets) ?? ScreenAuditAssetExpectations()
        severityOverrides = try container.decodeIfPresent([String: ScreenAuditSeverity].self, forKey: .severityOverrides) ?? [:]
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

/// Named region rectangle in screenshot pixel coordinates.
public struct ScreenAuditRegion: Codable, Equatable, Sendable {
    /// Region name used in findings and reports.
    public let name: String

    /// Minimum x-coordinate in pixels.
    public let x: Int

    /// Minimum y-coordinate in pixels.
    public let y: Int

    /// Region width in pixels.
    public let width: Int

    /// Region height in pixels.
    public let height: Int

    /// Creates a named screenshot region.
    /// - Parameters:
    ///   - name: Region name used in findings and reports.
    ///   - x: Minimum x-coordinate in pixels.
    ///   - y: Minimum y-coordinate in pixels.
    ///   - width: Region width in pixels.
    ///   - height: Region height in pixels.
    public init(name: String, x: Int, y: Int, width: Int, height: Int) {
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Region collections available to visual rules.
public struct ScreenAuditRegionSet: Codable, Equatable, Sendable {
    /// Regions that should receive stricter visual validation later.
    public let protected: [ScreenAuditRegion]

    /// Regions ignored by broad visual comparisons.
    public let ignored: [ScreenAuditRegion]

    /// Regions that should be inspected for high-signal visual defects.
    public let critical: [ScreenAuditRegion]

    /// Creates a region set.
    /// - Parameters:
    ///   - protected: Regions that should receive stricter visual validation later.
    ///   - ignored: Regions ignored by broad visual comparisons.
    ///   - critical: Regions that should be inspected for high-signal visual defects.
    public init(
        protected: [ScreenAuditRegion] = [],
        ignored: [ScreenAuditRegion] = [],
        critical: [ScreenAuditRegion] = []
    ) {
        self.protected = protected
        self.ignored = ignored
        self.critical = critical
    }

    private enum CodingKeys: String, CodingKey {
        case protected
        case ignored
        case critical
    }

    /// Decodes region collections, defaulting omitted collections to empty arrays.
    /// - Parameter decoder: Source decoder.
    /// - Throws: Decoding errors.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protected = try container.decodeIfPresent([ScreenAuditRegion].self, forKey: .protected) ?? []
        ignored = try container.decodeIfPresent([ScreenAuditRegion].self, forKey: .ignored) ?? []
        critical = try container.decodeIfPresent([ScreenAuditRegion].self, forKey: .critical) ?? []
    }
}

/// Baseline comparison settings for one screen.
public struct ScreenAuditBaselineExpectation: Codable, Equatable, Sendable {
    /// Baseline PNG path relative to the configured baseline directory.
    public let referencePath: String

    /// Maximum allowed mismatched-pixel ratio after ignored regions are removed.
    public let maxMismatchRatio: Double

    /// Creates a baseline expectation.
    /// - Parameters:
    ///   - referencePath: Baseline PNG path relative to the configured baseline directory.
    ///   - maxMismatchRatio: Maximum allowed mismatched-pixel ratio.
    public init(referencePath: String, maxMismatchRatio: Double = 0.0) {
        self.referencePath = referencePath
        self.maxMismatchRatio = maxMismatchRatio
    }
}

/// Asset quality facts supplied by a project-specific art or screenshot pipeline.
public struct ScreenAuditAssetExpectations: Codable, Equatable, Sendable {
    /// Fallback-art confidence facts to surface as advisory findings.
    public let fallbackArt: [ScreenAuditFallbackArtExpectation]

    /// Creates asset quality expectations.
    /// - Parameter fallbackArt: Fallback-art confidence facts to surface as advisory findings.
    public init(fallbackArt: [ScreenAuditFallbackArtExpectation] = []) {
        self.fallbackArt = fallbackArt
    }
}

/// Confidence fact for one fallback-art candidate used by a screen.
public struct ScreenAuditFallbackArtExpectation: Codable, Equatable, Sendable {
    /// Project-defined asset or region name.
    public let name: String

    /// Confidence score from the upstream pipeline, from 0.0 to 1.0.
    public let confidence: Double

    /// Minimum acceptable confidence before a warning is emitted.
    public let minimumConfidence: Double

    /// Optional project-specific explanation included in finding evidence.
    public let note: String?

    /// Creates a fallback-art confidence fact.
    /// - Parameters:
    ///   - name: Project-defined asset or region name.
    ///   - confidence: Confidence score from the upstream pipeline, from 0.0 to 1.0.
    ///   - minimumConfidence: Minimum acceptable confidence before a warning is emitted.
    ///   - note: Optional project-specific explanation included in finding evidence.
    public init(
        name: String,
        confidence: Double,
        minimumConfidence: Double = 0.75,
        note: String? = nil
    ) {
        self.name = name
        self.confidence = confidence
        self.minimumConfidence = minimumConfidence
        self.note = note
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
