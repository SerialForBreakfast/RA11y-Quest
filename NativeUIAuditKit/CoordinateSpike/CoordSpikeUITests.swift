import XCTest

// Measures three coordinate systems for the CoordSpikeView fixture and
// compares them against declared ground truth.
// See NativeUIAuditKit/Research/CoordinateSpike.md for setup and protocol.

final class CoordSpikeUITests: XCTestCase {

    // Declared ground truth (points, portrait, any device width).
    private let declared: [(id: String, rect: CGRect)] = [
        ("coord_spike_button",    CGRect(x: 40, y: 100, width: 200, height: 44)),
        ("coord_spike_textfield", CGRect(x: 40, y: 164, width: 280, height: 44)),
        ("coord_spike_label",     CGRect(x: 40, y: 228, width: 200, height: 30)),
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testCoordinateAlignment() throws {
        let scale = try XCTUnwrap(
            app.value(forKey: "screenScale") as? CGFloat,
            "Could not read screen scale — run on a simulator, not device"
        )
        print("[CoordSpike] Scale factor: \(scale)")

        var maxDeltaPx: CGFloat = 0

        for spec in declared {
            let element = app.otherElements[spec.id]
                .firstMatch
                .exists
                ? app.otherElements[spec.id].firstMatch
                : app.buttons[spec.id].firstMatch

            XCTAssertTrue(element.waitForExistence(timeout: 2), "Element not found: \(spec.id)")

            let actual = element.frame
            let decl = spec.rect
            let dx = abs(actual.minX - decl.minX)
            let dy = abs(actual.minY - decl.minY)
            let dw = abs(actual.width - decl.width)
            let dh = abs(actual.height - decl.height)

            let pixelActual = CGRect(
                x: actual.minX * scale,
                y: actual.minY * scale,
                width: actual.width * scale,
                height: actual.height * scale
            )
            let pixelDecl = CGRect(
                x: decl.minX * scale,
                y: decl.minY * scale,
                width: decl.width * scale,
                height: decl.height * scale
            )
            let maxEdgeDelta = max(
                abs(pixelActual.minX - pixelDecl.minX),
                abs(pixelActual.minY - pixelDecl.minY),
                abs(pixelActual.maxX - pixelDecl.maxX),
                abs(pixelActual.maxY - pixelDecl.maxY)
            )
            maxDeltaPx = max(maxDeltaPx, maxEdgeDelta)

            print("""
[CoordSpike] Element: \(spec.id)
  Declared (pt):    x=\(Int(decl.minX)) y=\(Int(decl.minY)) w=\(Int(decl.width)) h=\(Int(decl.height))
  XCUIElement (pt): x=\(Int(actual.minX)) y=\(Int(actual.minY)) w=\(Int(actual.width)) h=\(Int(actual.height))
  Delta (pt):       dx=\(String(format: "%.2f", dx)) dy=\(String(format: "%.2f", dy)) dw=\(String(format: "%.2f", dw)) dh=\(String(format: "%.2f", dh))
  Pixel actual:     x=\(Int(pixelActual.minX)) y=\(Int(pixelActual.minY)) w=\(Int(pixelActual.width)) h=\(Int(pixelActual.height))
  Pixel expected:   x=\(Int(pixelDecl.minX)) y=\(Int(pixelDecl.minY)) w=\(Int(pixelDecl.width)) h=\(Int(pixelDecl.height))
  Max edge delta:   \(String(format: "%.2f", maxEdgeDelta)) px
""")

            XCTAssertLessThanOrEqual(dx, 2, "\(spec.id): x delta exceeds 2pt")
            XCTAssertLessThanOrEqual(dy, 2, "\(spec.id): y delta exceeds 2pt")
            XCTAssertLessThanOrEqual(dw, 2, "\(spec.id): width delta exceeds 2pt")
            XCTAssertLessThanOrEqual(dh, 2, "\(spec.id): height delta exceeds 2pt")
            XCTAssertLessThanOrEqual(maxEdgeDelta, 2, "\(spec.id): pixel edge delta exceeds 2px")
        }

        print("[CoordSpike] Max pixel delta across all elements: \(String(format: "%.2f", maxDeltaPx)) px")

        // Capture screenshot for manual verification.
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "coord_spike_screenshot_\(Int(scale))x"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Bonus: verify that a partially-occluded element's frame clips to visible rect.
    // Add a clipped element to CoordSpikeView and un-skip this test when ready.
    func skip_testClippedElementBounds() {
        let clipped = app.otherElements["coord_spike_clipped"].firstMatch
        guard clipped.exists else { return }
        print("[CoordSpike] Clipped element frame: \(clipped.frame)")
        // Compare against the declared clipping rect and record delta.
    }
}
