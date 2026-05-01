import Foundation
import XCTest
@testable import ScreenAuditKit

/// Tests JSON contract decoding and validation behavior.
final class ScreenAuditContractTests: XCTestCase {
    /// Verifies a representative contract fixture decodes into typed schema models.
    func testValidContractFixtureDecodes() throws {
        let contractSet = try decodeFixture(named: "valid-contracts")

        XCTAssertEqual(contractSet.schemaVersion, 1)
        XCTAssertEqual(contractSet.projectName, "Fixture App")
        XCTAssertEqual(contractSet.screens.count, 1)

        let screen = try XCTUnwrap(contractSet.screens.first)
        XCTAssertEqual(screen.id, "hub")
        XCTAssertEqual(screen.filename, "01_Hub.png")
        XCTAssertEqual(screen.role, .entry)
        XCTAssertEqual(screen.pedagogyRole, .introduce)
        XCTAssertEqual(screen.severityOverrides["requiredTextMissing"], .error)
        XCTAssertEqual(screen.text.required, ["Quest Board", "Start"])
        XCTAssertEqual(screen.assets.fallbackArt.count, 1)
        XCTAssertEqual(screen.assets.fallbackArt.first?.name, "hero-image")
        XCTAssertEqual(screen.assets.fallbackArt.first?.confidence, 0.92)
        XCTAssertEqual(contractSet.flows.count, 1)
        XCTAssertEqual(contractSet.flows.first?.id, "onboarding")
        XCTAssertEqual(contractSet.flows.first?.steps.first?.screenID, "hub")
        XCTAssertEqual(contractSet.flows.first?.steps.first?.required, true)

        let device = try XCTUnwrap(screen.devices.first)
        XCTAssertEqual(device.label, "iPhone_large")
        XCTAssertEqual(device.family, .iPhone)
        XCTAssertEqual(device.pixelWidth, 1290)
        XCTAssertEqual(device.pixelHeight, 2796)
        XCTAssertEqual(device.orientation, .portrait)
    }

    /// Verifies unsupported schema versions fail before rule evaluation.
    func testUnsupportedSchemaVersionThrowsClearError() throws {
        let data = try fixtureData(named: "unsupported-schema-contracts")

        XCTAssertThrowsError(try ScreenAuditContractSet.decode(from: data)) { error in
            XCTAssertEqual(
                error as? ScreenAuditContractError,
                .unsupportedSchemaVersion(actual: 99, supported: 1)
            )
            XCTAssertEqual(
                error.localizedDescription,
                "Unsupported screen audit contract schema version 99. Supported version: 1."
            )
        }
    }

    /// Verifies required screen fields are validated after decoding.
    func testMissingRequiredScreenFieldThrowsClearError() throws {
        let data = try fixtureData(named: "missing-required-field-contracts")

        XCTAssertThrowsError(try ScreenAuditContractSet.decode(from: data)) { error in
            XCTAssertEqual(
                error as? ScreenAuditContractError,
                .emptyRequiredField(name: "screens[].id")
            )
            XCTAssertEqual(
                error.localizedDescription,
                "Screen audit contract field `screens[].id` must not be empty."
            )
        }
    }

    /// Loads and decodes a JSON fixture from the test bundle.
    /// - Parameter name: Fixture basename without the `.json` extension.
    /// - Returns: Validated contract set.
    private func decodeFixture(named name: String) throws -> ScreenAuditContractSet {
        let data = try fixtureData(named: name)
        return try ScreenAuditContractSet.decode(from: data)
    }

    /// Loads raw fixture data from the test bundle.
    /// - Parameter name: Fixture basename without the `.json` extension.
    /// - Returns: Fixture data.
    private func fixtureData(named name: String) throws -> Data {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: fixtureURL)
    }
}
