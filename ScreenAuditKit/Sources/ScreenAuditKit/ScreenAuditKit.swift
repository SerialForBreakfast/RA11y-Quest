import Foundation

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
          \(executableName) validate --screenshots <dir> --contracts <file> --output <dir>

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
    private let validator: ScreenAuditValidator

    /// Creates a command-line runner.
    /// - Parameter validator: Filesystem validator used by the `validate` command.
    public init(validator: ScreenAuditValidator = ScreenAuditValidator()) {
        self.validator = validator
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
            let result = try validator.validate(
                screenshotsDirectory: parsedArguments.screenshotsDirectory,
                contractFile: parsedArguments.contractFile,
                outputDirectory: parsedArguments.outputDirectory
            )
            standardOutput("Evidence report: \(parsedArguments.outputDirectory.appendingPathComponent("evidence.json").path)")
            standardOutput("Findings report: \(parsedArguments.outputDirectory.appendingPathComponent("findings.json").path)")
            standardOutput("Markdown summary: \(parsedArguments.outputDirectory.appendingPathComponent("summary.md").path)")

            if result.findingsReport.hasHardFailures {
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

    init(arguments: [String]) throws {
        var screenshotsPath: String?
        var contractsPath: String?
        var outputPath: String?

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
    }
}

private enum ScreenAuditCLIArgumentError: Error, LocalizedError {
    case missingRequiredFlag(String)
    case missingValue(flag: String)
    case unsupportedFlag(String)

    var errorDescription: String? {
        switch self {
        case let .missingRequiredFlag(flag):
            "Missing required flag: \(flag)."
        case let .missingValue(flag):
            "Missing value for flag: \(flag)."
        case let .unsupportedFlag(flag):
            "Unsupported flag: \(flag)."
        }
    }
}
