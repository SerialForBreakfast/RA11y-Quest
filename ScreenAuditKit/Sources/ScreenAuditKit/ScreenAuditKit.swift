import Foundation

/// Selects which OCR engine populates ``ScreenAuditOCRTranscript`` during validation.
public enum ScreenAuditOCROption: String, Sendable, Equatable {
    /// No OCR; text rules are surfaced as skipped info findings.
    case none
    /// Apple Vision text recognition on decoded PNG bitmaps (macOS host).
    case vision
}

/// Namespace for package-level metadata and static command help.
public enum ScreenAuditKit {
    /// Local package version used while the package is developed inside RA11y.
    public static let version = "0.1.0-local"

    /// Returns command-line usage text for the `screenaudit` executable.
    /// - Parameter executableName: Name to show in command examples.
    /// - Returns: Stable help text suitable for terminal output and tests.
    public static func helpText(executableName: String = "screenaudit") -> String {
        """
        ScreenAuditKit \(version)

        Usage:
          \(executableName) --help
          \(executableName) --version
          \(executableName) validate --screenshots <dir> --contracts <file> --output <dir> [--baselines <dir>] [--ocr none|vision]

        Commands:
          validate    Validate screenshots against contracts.

        Exit codes:
          0  Success.
          1  Validation completed with hard findings.
          2  Usage or configuration error.
          3  Input decoding or file access error.
          4  Analyzer runtime error.
        """
    }
}

/// Stable process exit codes used by the `screenaudit` command-line interface.
public enum ScreenAuditExitCode: Int32 {
    /// Command completed successfully.
    case success = 0

    /// Validation completed and found hard failures.
    case validationFailed = 1

    /// Command-line usage or configuration was invalid.
    case usageError = 2

    /// Required input could not be read or decoded.
    case inputError = 3

    /// Analysis failed during execution.
    case runtimeError = 4
}

/// Minimal command-line runner for the `screenaudit` executable.
public struct ScreenAuditCLI {
    /// Optional validator override for tests that inject a custom dependency graph.
    private let validatorOverride: ScreenAuditValidator?

    /// Creates a command-line runner using the default validator factory per `--ocr`.
    public init() {
        self.validatorOverride = nil
    }

    /// Creates a command-line runner with a fixed validator (tests only).
    /// - Parameter validatorOverride: Validator used for every `validate` invocation.
    public init(validatorOverride: ScreenAuditValidator) {
        self.validatorOverride = validatorOverride
    }

    /// Runs the command-line interface with explicit output sinks.
    /// - Parameters:
    ///   - arguments: Command-line arguments excluding the executable path.
    ///   - standardOutput: Sink for normal command output.
    ///   - standardError: Sink for error output.
    /// - Returns: Process exit code.
    public func run(
        arguments: [String],
        standardOutput: (String) -> Void,
        standardError: (String) -> Void
    ) -> Int32 {
        if arguments.isEmpty || arguments == ["--help"] || arguments == ["help"] {
            standardOutput(ScreenAuditKit.helpText())
            return ScreenAuditExitCode.success.rawValue
        }

        if arguments == ["--version"] || arguments == ["version"] {
            standardOutput(ScreenAuditKit.version)
            return ScreenAuditExitCode.success.rawValue
        }

        if arguments.first == "validate" {
            return runValidate(
                arguments: Array(arguments.dropFirst()),
                standardOutput: standardOutput,
                standardError: standardError
            )
        }

        standardError("Unsupported arguments: \(arguments.joined(separator: " "))")
        standardError("Run `screenaudit --help` for usage.")
        return ScreenAuditExitCode.usageError.rawValue
    }

    private func runValidate(
        arguments: [String],
        standardOutput: (String) -> Void,
        standardError: (String) -> Void
    ) -> Int32 {
        let parsedArguments: ValidateArguments
        do {
            parsedArguments = try ValidateArguments(arguments: arguments)
        } catch {
            standardError(error.localizedDescription)
            standardError("Run `screenaudit --help` for usage.")
            return ScreenAuditExitCode.usageError.rawValue
        }

        do {
            let validator = validatorOverride ?? ScreenAuditValidator.makeDefault(ocr: parsedArguments.ocr)
            let result = try validator.validate(
                screenshotsDirectory: parsedArguments.screenshotsDirectory,
                contractFile: parsedArguments.contractFile,
                outputDirectory: parsedArguments.outputDirectory,
                baselineDirectory: parsedArguments.baselineDirectory
            )
            standardOutput("Evidence report: \(parsedArguments.outputDirectory.appendingPathComponent("evidence.json").path)")
            standardOutput("Findings report: \(parsedArguments.outputDirectory.appendingPathComponent("findings.json").path)")
            standardOutput("Markdown summary: \(parsedArguments.outputDirectory.appendingPathComponent("summary.md").path)")
            standardOutput("Flow report: \(parsedArguments.outputDirectory.appendingPathComponent("flow.json").path)")
            standardOutput("Flow summary: \(parsedArguments.outputDirectory.appendingPathComponent("flow-summary.md").path)")

            if result.findingsReport.hasHardFailures {
                let summaryPath = parsedArguments.outputDirectory.appendingPathComponent("summary.md").path
                standardError("Human-readable triage: \(summaryPath)")
                standardError("Screen audit completed with hard failures.")
                return ScreenAuditExitCode.validationFailed.rawValue
            }

            standardOutput("Screen audit completed without hard failures.")
            return ScreenAuditExitCode.success.rawValue
        } catch let error as ScreenAuditValidationError {
            standardError(error.localizedDescription)
            return ScreenAuditExitCode.inputError.rawValue
        } catch let error as ScreenAuditContractError {
            standardError(error.localizedDescription)
            return ScreenAuditExitCode.inputError.rawValue
        } catch let error as ScreenAuditEvidenceError {
            standardError(error.localizedDescription)
            return ScreenAuditExitCode.inputError.rawValue
        } catch {
            standardError(error.localizedDescription)
            return ScreenAuditExitCode.runtimeError.rawValue
        }
    }
}

private struct ValidateArguments {
    let screenshotsDirectory: URL
    let contractFile: URL
    let outputDirectory: URL
    let baselineDirectory: URL?
    let ocr: ScreenAuditOCROption

    init(arguments: [String]) throws {
        var screenshotsPath: String?
        var contractsPath: String?
        var outputPath: String?
        var baselinesPath: String?
        var ocrRaw: String?

        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else {
                throw ScreenAuditCLIArgumentError.missingValue(flag: flag)
            }

            let value = arguments[index + 1]
            switch flag {
            case "--screenshots":
                screenshotsPath = value
            case "--contracts":
                contractsPath = value
            case "--output":
                outputPath = value
            case "--baselines":
                baselinesPath = value
            case "--ocr":
                ocrRaw = value
            default:
                throw ScreenAuditCLIArgumentError.unsupportedFlag(flag)
            }
            index += 2
        }

        guard let screenshotsPath else {
            throw ScreenAuditCLIArgumentError.missingRequiredFlag("--screenshots")
        }
        guard let contractsPath else {
            throw ScreenAuditCLIArgumentError.missingRequiredFlag("--contracts")
        }
        guard let outputPath else {
            throw ScreenAuditCLIArgumentError.missingRequiredFlag("--output")
        }

        screenshotsDirectory = URL(fileURLWithPath: screenshotsPath)
        contractFile = URL(fileURLWithPath: contractsPath)
        outputDirectory = URL(fileURLWithPath: outputPath)
        baselineDirectory = baselinesPath.map { URL(fileURLWithPath: $0) }

        if let ocrRaw {
            guard let parsed = ScreenAuditOCROption(rawValue: ocrRaw) else {
                throw ScreenAuditCLIArgumentError.invalidOCRMode(ocrRaw)
            }
            ocr = parsed
        } else {
            ocr = .none
        }
    }
}

private enum ScreenAuditCLIArgumentError: Error, LocalizedError {
    case missingRequiredFlag(String)
    case missingValue(flag: String)
    case unsupportedFlag(String)
    case invalidOCRMode(String)

    var errorDescription: String? {
        switch self {
        case let .missingRequiredFlag(flag):
            "Missing required flag: \(flag)."
        case let .missingValue(flag):
            "Missing value for flag: \(flag)."
        case let .unsupportedFlag(flag):
            "Unsupported flag: \(flag)."
        case let .invalidOCRMode(value):
            "Invalid --ocr value `\(value)`. Use `none` or `vision`."
        }
    }
}
