import Foundation
import XCTest
@testable import ScreenAuditKit

/// Tests command-line argument handling without spawning a process.
final class ScreenAuditCLITests: XCTestCase {
    /// Verifies `--help` writes usage text and exits successfully.
    func testHelpReturnsSuccess() {
        let result = runCLI(arguments: ["--help"])

        XCTAssertEqual(result.exitCode, ScreenAuditExitCode.success.rawValue)
        XCTAssertTrue(result.output.joined(separator: "\n").contains("ScreenAuditKit"))
        XCTAssertTrue(result.error.isEmpty)
    }

    /// Verifies `--version` writes only the package version.
    func testVersionReturnsSuccess() {
        let result = runCLI(arguments: ["--version"])

        XCTAssertEqual(result.exitCode, ScreenAuditExitCode.success.rawValue)
        XCTAssertEqual(result.output, ["0.1.0-local"])
        XCTAssertTrue(result.error.isEmpty)
    }

    /// Verifies unsupported arguments fail with a usage error.
    func testUnsupportedArgumentsReturnUsageError() {
        let result = runCLI(arguments: ["validate"])

        XCTAssertEqual(result.exitCode, ScreenAuditExitCode.usageError.rawValue)
        XCTAssertTrue(result.output.isEmpty)
        XCTAssertEqual(result.error.count, 2)
    }

    /// Verifies `validate` writes reports and exits successfully when no hard findings exist.
    func testValidateSuccessWritesReports() throws {
        let fixture = try makeValidationFixture(
            name: "success",
            contractJSON: """
            {
              "schemaVersion": 1,
              "projectName": "CLI Fixture",
              "screens": [
                {
                  "id": "pixel",
                  "filename": "pixel.png",
                  "devices": [
                    {
                      "label": "fixture",
                      "pixelWidth": 1,
                      "pixelHeight": 1
                    }
                  ],
                  "text": {
                    "required": [],
                    "optional": [],
                    "forbidden": []
                  },
                  "severityOverrides": {}
                }
              ]
            }
            """
        )

        let result = runCLI(arguments: validateArguments(for: fixture))

        XCTAssertEqual(result.exitCode, ScreenAuditExitCode.success.rawValue)
        XCTAssertTrue(result.output.contains("Screen audit completed without hard failures."))
        XCTAssertTrue(result.error.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("evidence.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("findings.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("summary.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("flow.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.outputDirectory.appendingPathComponent("flow-summary.md").path))

        let findingsData = try Data(contentsOf: fixture.outputDirectory.appendingPathComponent("findings.json"))
        let findingsReport = try JSONDecoder().decode(ScreenAuditFindingsReport.self, from: findingsData)
        XCTAssertEqual(findingsReport.findings.count, 0)

        let flowData = try Data(contentsOf: fixture.outputDirectory.appendingPathComponent("flow.json"))
        let flowReport = try JSONDecoder().decode(ScreenAuditFlowReport.self, from: flowData)
        XCTAssertTrue(flowReport.flows.isEmpty)
    }

    /// Verifies `validate` exits with validation failure when deterministic findings include errors.
    func testValidateHardFailureReturnsValidationFailed() throws {
        let fixture = try makeValidationFixture(
            name: "hard-failure",
            contractJSON: """
            {
              "schemaVersion": 1,
              "projectName": "CLI Fixture",
              "screens": [
                {
                  "id": "pixel",
                  "filename": "pixel.png",
                  "devices": [
                    {
                      "label": "fixture",
                      "pixelWidth": 2,
                      "pixelHeight": 2
                    }
                  ],
                  "text": {
                    "required": [],
                    "optional": [],
                    "forbidden": []
                  },
                  "severityOverrides": {}
                }
              ]
            }
            """
        )

        let result = runCLI(arguments: validateArguments(for: fixture))

        XCTAssertEqual(result.exitCode, ScreenAuditExitCode.validationFailed.rawValue)
        XCTAssertTrue(result.error.contains("Screen audit completed with hard failures."))

        let findingsData = try Data(contentsOf: fixture.outputDirectory.appendingPathComponent("findings.json"))
        let findingsReport = try JSONDecoder().decode(ScreenAuditFindingsReport.self, from: findingsData)
        XCTAssertEqual(findingsReport.findings.first?.ruleID, .dimensionMismatch)
    }

    /// Verifies missing input directories map to the input-error exit code.
    func testValidateMissingScreenshotDirectoryReturnsInputError() throws {
        let fixture = try makeValidationFixture(
            name: "missing-input",
            contractJSON: """
            {
              "schemaVersion": 1,
              "projectName": "CLI Fixture",
              "screens": []
            }
            """
        )
        let missingDirectory = fixture.rootDirectory.appendingPathComponent("does-not-exist")

        let result = runCLI(arguments: [
            "validate",
            "--screenshots", missingDirectory.path,
            "--contracts", fixture.contractFile.path,
            "--output", fixture.outputDirectory.path
        ])

        XCTAssertEqual(result.exitCode, ScreenAuditExitCode.inputError.rawValue)
        XCTAssertEqual(result.error, ["Required input does not exist: `\(missingDirectory.path)`."])
    }

    /// Runs the CLI with captured output arrays.
    /// - Parameter arguments: Command-line arguments excluding executable path.
    /// - Returns: Captured process result.
    private func runCLI(arguments: [String]) -> CapturedCLIResult {
        let cli = ScreenAuditCLI()
        var output: [String] = []
        var error: [String] = []
        let exitCode = cli.run(
            arguments: arguments,
            standardOutput: { output.append($0) },
            standardError: { error.append($0) }
        )

        return CapturedCLIResult(exitCode: exitCode, output: output, error: error)
    }

    /// Builds validate command arguments for a fixture.
    /// - Parameter fixture: Validation fixture.
    /// - Returns: CLI argument array.
    private func validateArguments(for fixture: ValidationFixture) -> [String] {
        [
            "validate",
            "--screenshots", fixture.screenshotsDirectory.path,
            "--contracts", fixture.contractFile.path,
            "--output", fixture.outputDirectory.path
        ]
    }

    /// Creates a filesystem fixture for CLI validation tests.
    /// - Parameters:
    ///   - name: Fixture directory name.
    ///   - contractJSON: Contract JSON to write.
    /// - Returns: Created fixture paths.
    private func makeValidationFixture(name: String, contractJSON: String) throws -> ValidationFixture {
        let rootDirectory = packageRootURL()
            .appendingPathComponent(".build")
            .appendingPathComponent("test-artifacts")
            .appendingPathComponent("cli")
            .appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: rootDirectory.path) {
            try FileManager.default.removeItem(at: rootDirectory)
        }

        let screenshotsDirectory = rootDirectory.appendingPathComponent("screenshots")
        let outputDirectory = rootDirectory.appendingPathComponent("reports")
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)

        let screenshotFile = screenshotsDirectory.appendingPathComponent("pixel.png")
        try transparentPixelPNGData().write(to: screenshotFile, options: .atomic)

        let contractFile = rootDirectory.appendingPathComponent("contracts.json")
        try contractJSON.write(to: contractFile, atomically: true, encoding: .utf8)

        return ValidationFixture(
            rootDirectory: rootDirectory,
            screenshotsDirectory: screenshotsDirectory,
            contractFile: contractFile,
            outputDirectory: outputDirectory
        )
    }

    /// Decodes a tiny transparent PNG fixture.
    /// - Returns: PNG data.
    private func transparentPixelPNGData() throws -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        return try XCTUnwrap(Data(base64Encoded: base64))
    }

    /// Resolves the package root from this source file path.
    /// - Returns: Package root URL.
    private func packageRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

/// Captured result from a direct CLI runner invocation.
private struct CapturedCLIResult {
    /// Process exit code returned by the CLI runner.
    let exitCode: Int32

    /// Lines written to standard output.
    let output: [String]

    /// Lines written to standard error.
    let error: [String]
}

/// Filesystem paths used by one validation CLI fixture.
private struct ValidationFixture {
    /// Root fixture directory.
    let rootDirectory: URL

    /// Screenshot input directory.
    let screenshotsDirectory: URL

    /// Contract JSON file.
    let contractFile: URL

    /// Report output directory.
    let outputDirectory: URL
}
