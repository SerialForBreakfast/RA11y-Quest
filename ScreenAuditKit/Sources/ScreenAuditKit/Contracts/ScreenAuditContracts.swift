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

    /// Optional asset provenance file path relative to this contract file.
    public let assetProvenancePath: String?

    /// Screen-level contracts that define expected screenshot state.
    public let screens: [ScreenAuditScreenContract]

    /// Optional ordered flows that group screens into reviewable journeys.
    public let flows: [ScreenAuditFlowContract]

    /// Creates a contract set after validating schema and required fields.
    /// - Parameters:
    ///   - schemaVersion: Schema version declared by the contract file.
    ///   - projectName: Human-readable project or contract collection name.
    ///   - assetProvenancePath: Optional asset provenance file path relative to this contract file.
    ///   - screens: Screen-level contracts.
    ///   - flows: Optional ordered flows that group screens into reviewable journeys.
    /// - Throws: `ScreenAuditContractError` when required contract metadata is invalid.
    public init(
        schemaVersion: Int,
        projectName: String,
        assetProvenancePath: String? = nil,
        screens: [ScreenAuditScreenContract],
        flows: [ScreenAuditFlowContract] = []
    ) throws {
        try Self.validateSchemaVersion(schemaVersion)
        try Self.validateRequired(projectName, name: "projectName")

        self.schemaVersion = schemaVersion
        self.projectName = projectName
        self.assetProvenancePath = assetProvenancePath
        self.screens = screens
        self.flows = flows
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case projectName
        case assetProvenancePath
        case screens
        case flows
    }

    /// Decodes a contract set, defaulting optional flow data for older contracts.
    /// - Parameter decoder: Source decoder.
    /// - Throws: Decoding errors.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        projectName = try container.decode(String.self, forKey: .projectName)
        assetProvenancePath = try container.decodeIfPresent(String.self, forKey: .assetProvenancePath)
        screens = try container.decodeIfPresent([ScreenAuditScreenContract].self, forKey: .screens) ?? []
        flows = try container.decodeIfPresent([ScreenAuditFlowContract].self, forKey: .flows) ?? []
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
        for flow in decoded.flows {
            try flow.validate()
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

/// Ordered group of screenshots that should read as a coherent user journey.
public struct ScreenAuditFlowContract: Codable, Equatable, Sendable {
    /// Stable flow identifier used in reports and findings.
    public let id: String

    /// Human-readable flow title.
    public let title: String

    /// Ordered steps that make up the flow.
    public let steps: [ScreenAuditFlowStep]

    /// Creates a flow contract.
    /// - Parameters:
    ///   - id: Stable flow identifier used in reports and findings.
    ///   - title: Human-readable flow title.
    ///   - steps: Ordered steps that make up the flow.
    public init(
        id: String,
        title: String,
        steps: [ScreenAuditFlowStep]
    ) {
        self.id = id
        self.title = title
        self.steps = steps
    }

    /// Validates required flow metadata after decoding.
    /// - Throws: `ScreenAuditContractError` when required values are empty.
    public func validate() throws {
        try ScreenAuditContractSet.validateRequired(id, name: "flows[].id")
        try ScreenAuditContractSet.validateRequired(title, name: "flows[].title")
        for step in steps {
            try step.validate()
        }
    }
}

/// One ordered screen reference inside a flow contract.
public struct ScreenAuditFlowStep: Codable, Equatable, Sendable {
    /// Screen contract ID expected at this point in the flow.
    public let screenID: String

    /// Whether missing evidence for this step should be a hard failure.
    public let required: Bool

    /// When true and this step's screenshot is present, the immediately preceding flow step's
    /// screen must also have screenshot evidence (co-presence check for linear journeys).
    public let requirePreviousStepPresent: Bool

    /// Optional project-specific note for reviewers.
    public let note: String?

    /// Creates a flow step.
    /// - Parameters:
    ///   - screenID: Screen contract ID expected at this point in the flow.
    ///   - required: Whether missing evidence for this step should be a hard failure.
    ///   - requirePreviousStepPresent: When true, a present current step requires the previous step's PNG too.
    ///   - note: Optional project-specific note for reviewers.
    public init(
        screenID: String,
        required: Bool = true,
        requirePreviousStepPresent: Bool = false,
        note: String? = nil
    ) {
        self.screenID = screenID
        self.required = required
        self.requirePreviousStepPresent = requirePreviousStepPresent
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case screenID
        case required
        case requirePreviousStepPresent
        case note
    }

    /// Decodes a flow step, defaulting `required` to true for concise contracts.
    /// - Parameter decoder: Source decoder.
    /// - Throws: Decoding errors.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        screenID = try container.decode(String.self, forKey: .screenID)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? true
        requirePreviousStepPresent = try container.decodeIfPresent(Bool.self, forKey: .requirePreviousStepPresent) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    /// Encodes this step for JSON contract files.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(screenID, forKey: .screenID)
        try container.encode(required, forKey: .required)
        if requirePreviousStepPresent {
            try container.encode(true, forKey: .requirePreviousStepPresent)
        }
        try container.encodeIfPresent(note, forKey: .note)
    }

    /// Validates required flow step metadata after decoding.
    /// - Throws: `ScreenAuditContractError` when required values are empty.
    public func validate() throws {
        try ScreenAuditContractSet.validateRequired(screenID, name: "flows[].steps[].screenID")
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

    /// Optional coordinate space used to scale this region to the inspected screenshot.
    public let coordinateSpace: ScreenAuditCoordinateSpace?

    /// Creates a named screenshot region.
    /// - Parameters:
    ///   - name: Region name used in findings and reports.
    ///   - x: Minimum x-coordinate in pixels.
    ///   - y: Minimum y-coordinate in pixels.
    ///   - width: Region width in pixels.
    ///   - height: Region height in pixels.
    ///   - coordinateSpace: Optional coordinate space used to scale this region to the inspected screenshot.
    public init(
        name: String,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        coordinateSpace: ScreenAuditCoordinateSpace? = nil
    ) {
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.coordinateSpace = coordinateSpace
    }

    /// Returns this region scaled to a screenshot size when a coordinate space is declared.
    /// - Parameters:
    ///   - pixelWidth: Target screenshot width.
    ///   - pixelHeight: Target screenshot height.
    /// - Returns: Region in target screenshot pixel coordinates.
    public func scaled(toPixelWidth pixelWidth: Int, pixelHeight: Int) -> ScreenAuditRegion {
        guard
            let coordinateSpace,
            coordinateSpace.width > 0,
            coordinateSpace.height > 0
        else {
            return self
        }

        let widthScale = Double(pixelWidth) / Double(coordinateSpace.width)
        let heightScale = Double(pixelHeight) / Double(coordinateSpace.height)

        return ScreenAuditRegion(
            name: name,
            x: Int((Double(x) * widthScale).rounded()),
            y: Int((Double(y) * heightScale).rounded()),
            width: Int((Double(width) * widthScale).rounded()),
            height: Int((Double(height) * heightScale).rounded()),
            coordinateSpace: coordinateSpace
        )
    }
}

/// Pixel coordinate space used for responsive region scaling.
public struct ScreenAuditCoordinateSpace: Codable, Equatable, Sendable {
    /// Reference screenshot width.
    public let width: Int

    /// Reference screenshot height.
    public let height: Int

    /// Creates a coordinate space.
    /// - Parameters:
    ///   - width: Reference screenshot width.
    ///   - height: Reference screenshot height.
    public init(width: Int, height: Int) {
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

    /// Optional identifier for a provenance record that explains this asset.
    public let provenanceID: String?

    /// Creates a fallback-art confidence fact.
    /// - Parameters:
    ///   - name: Project-defined asset or region name.
    ///   - confidence: Confidence score from the upstream pipeline, from 0.0 to 1.0.
    ///   - minimumConfidence: Minimum acceptable confidence before a warning is emitted.
    ///   - note: Optional project-specific explanation included in finding evidence.
    ///   - provenanceID: Optional identifier for a provenance record that explains this asset.
    public init(
        name: String,
        confidence: Double,
        minimumConfidence: Double = 0.75,
        note: String? = nil,
        provenanceID: String? = nil
    ) {
        self.name = name
        self.confidence = confidence
        self.minimumConfidence = minimumConfidence
        self.note = note
        self.provenanceID = provenanceID
    }
}

/// Asset provenance records supplied by a project.
public struct ScreenAuditAssetProvenanceSet: Codable, Equatable, Sendable {
    /// Provenance records keyed by project-defined identifiers.
    public let assets: [ScreenAuditAssetProvenance]

    /// Creates a provenance set.
    /// - Parameter assets: Provenance records keyed by project-defined identifiers.
    public init(assets: [ScreenAuditAssetProvenance] = []) {
        self.assets = assets
    }

    /// Returns the provenance record for an asset identifier.
    /// - Parameter id: Asset identifier.
    /// - Returns: Matching provenance record, when present.
    public func asset(id: String) -> ScreenAuditAssetProvenance? {
        assets.first { $0.id == id }
    }
}

/// Provenance and review status for a visual asset.
public struct ScreenAuditAssetProvenance: Codable, Equatable, Sendable {
    /// Project-defined identifier.
    public let id: String

    /// Human-readable asset name.
    public let name: String

    /// Asset source category.
    public let source: ScreenAuditAssetSource

    /// Review and replacement status.
    public let authoringStatus: ScreenAuditAssetAuthoringStatus

    /// Source quality category.
    public let sourceQuality: ScreenAuditAssetSourceQuality

    /// Concrete risks a reviewer should understand.
    public let knownRisks: [String]

    /// Evidence paths or notes that support the provenance record.
    public let evidence: [String]

    /// Optional prose note.
    public let note: String?

    /// Creates an asset provenance record.
    /// - Parameters:
    ///   - id: Project-defined identifier.
    ///   - name: Human-readable asset name.
    ///   - source: Asset source category.
    ///   - authoringStatus: Review and replacement status.
    ///   - sourceQuality: Source quality category.
    ///   - knownRisks: Concrete risks a reviewer should understand.
    ///   - evidence: Evidence paths or notes that support the provenance record.
    ///   - note: Optional prose note.
    public init(
        id: String,
        name: String,
        source: ScreenAuditAssetSource,
        authoringStatus: ScreenAuditAssetAuthoringStatus,
        sourceQuality: ScreenAuditAssetSourceQuality,
        knownRisks: [String] = [],
        evidence: [String] = [],
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.authoringStatus = authoringStatus
        self.sourceQuality = sourceQuality
        self.knownRisks = knownRisks
        self.evidence = evidence
        self.note = note
    }
}

/// Source category for a visual asset.
public enum ScreenAuditAssetSource: String, Codable, Equatable, Sendable {
    /// Human-created or commissioned art.
    case humanAuthored

    /// Directed LLM image generation export.
    case llmAuthored

    /// Cropped from a mockup screenshot.
    case mockupCrop

    /// Placeholder or temporary art.
    case placeholder

    /// Generated procedurally or by script.
    case procedural

    /// Source is unknown.
    case unknown
}

/// Review status for a visual asset.
public enum ScreenAuditAssetAuthoringStatus: String, Codable, Equatable, Sendable {
    /// Final authored asset.
    case final

    /// Authored candidate that needs review.
    case reviewNeeded

    /// Temporary asset that should be replaced.
    case temporary

    /// Asset status is unknown.
    case unknown
}

/// Source quality category for a visual asset.
public enum ScreenAuditAssetSourceQuality: String, Codable, Equatable, Sendable {
    /// Production-ready source.
    case production

    /// Acceptable for review but not final.
    case review

    /// Bootstrap source used to unblock development.
    case bootstrap

    /// Known low-quality source.
    case low

    /// Source quality is unknown.
    case unknown
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
