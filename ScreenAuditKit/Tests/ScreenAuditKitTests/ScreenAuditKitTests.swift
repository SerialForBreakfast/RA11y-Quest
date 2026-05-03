import XCTest
@testable import ScreenAuditKit

/// Tests package-level metadata and static help text.
final class ScreenAuditKitTests: XCTestCase {
    /// Verifies the package version is exposed for command-line and report output.
    func testVersionIsLocalDevelopmentVersion() {
        XCTAssertEqual(ScreenAuditKit.version, "0.1.0-local")
    }

    /// Verifies help text names the planned validation command and exit codes.
    func testHelpTextDescribesPlannedCommandsAndExitCodes() {
        let helpText = ScreenAuditKit.helpText(executableName: "audit")

        XCTAssertTrue(helpText.contains("audit --help"))
        XCTAssertTrue(helpText.contains("validate"))
        XCTAssertTrue(helpText.contains("Exit codes"))
        XCTAssertTrue(helpText.contains("2  Usage or configuration error."))
        XCTAssertTrue(helpText.contains("--ocr"))
    }
}
