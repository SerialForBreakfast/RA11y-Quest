import XCTest
@testable import ScreenAuditKit

/// Tests package-level metadata and static help text.
final class ScreenAuditKitTests: XCTestCase {
    /// Verifies the package version is exposed for command-line and report output.
    func testVersionIsCurrentRelease() {
        XCTAssertEqual(ScreenAuditKit.version, "1.0.0")
    }

    /// Verifies help text names the planned validation command and exit codes.
    func testHelpTextDescribesPlannedCommandsAndExitCodes() {
        let helpText = ScreenAuditKit.helpText(executableName: "audit")

        XCTAssertTrue(helpText.contains("audit --help"))
        XCTAssertTrue(helpText.contains("validate"))
        XCTAssertTrue(helpText.contains("Exit codes"))
        XCTAssertTrue(helpText.contains("2  Usage or configuration error."))
        XCTAssertTrue(helpText.contains("--ocr"))
        XCTAssertTrue(helpText.contains("export-feature-walkthrough"))
    }
}
