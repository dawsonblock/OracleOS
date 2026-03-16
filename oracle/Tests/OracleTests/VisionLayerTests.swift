import XCTest
@testable import OracleLib

final class VisionLayerTests: XCTestCase {

    override func tearDown() {
        unsetenv("ORACLE_VISION_URL")
        unsetenv("ORACLE_VISION_BIN")
        unsetenv("ORACLE_CDP_PORT")
        super.tearDown()
    }

    func testScreenshotResultInitStoresFields() {
        let result = ScreenshotResult(
            base64PNG: "abc123",
            width: 640,
            height: 480,
            windowTitle: "Preview",
            mimeType: "image/png",
            windowX: 10,
            windowY: 20,
            windowWidth: 800,
            windowHeight: 600
        )

        XCTAssertEqual(result.base64PNG, "abc123")
        XCTAssertEqual(result.width, 640)
        XCTAssertEqual(result.height, 480)
        XCTAssertEqual(result.windowTitle, "Preview")
        XCTAssertEqual(result.windowWidth, 800)
    }

    func testCaptureFailureEquatableAssociatedValue() {
        let lhs = ScreenCapture.CaptureFailure.captureReturnedNil(windowID: 42)
        let rhs = ScreenCapture.CaptureFailure.captureReturnedNil(windowID: 42)
        XCTAssertEqual(lhs, rhs)
    }

    func testGroundResultInitStoresFields() {
        let result = VisionBridge.GroundResult(
            x: 11,
            y: 22,
            confidence: 0.8,
            raw: "raw",
            method: "crop-based",
            inferenceMs: 123
        )

        XCTAssertEqual(result.x, 11, accuracy: 0.001)
        XCTAssertEqual(result.y, 22, accuracy: 0.001)
        XCTAssertEqual(result.confidence, 0.8, accuracy: 0.001)
        XCTAssertEqual(result.method, "crop-based")
        XCTAssertEqual(result.inferenceMs, 123)
    }

    func testToolResultInitStoresFields() {
        let result = ToolResult(
            success: true,
            data: ["x": "100", "y": "200"],
            error: nil,
            suggestion: "looks good"
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.data["x"], "100")
        XCTAssertEqual(result.suggestion, "looks good")
        XCTAssertNil(result.error)
    }

    func testVisionBridgeHealthCheckReturnsNilForInvalidURL() {
        setenv("ORACLE_VISION_URL", "not-a-valid-url", 1)
        XCTAssertNil(VisionBridge.healthCheck())
    }

    func testVisionBridgeIsAvailableFalseForInvalidURL() {
        setenv("ORACLE_VISION_URL", "not-a-valid-url", 1)
        XCTAssertFalse(VisionBridge.isAvailable())
    }

    func testVisionBridgeGroundReturnsNilWhenUnavailable() {
        setenv("ORACLE_VISION_URL", "http://127.0.0.1:9", 1)
        setenv("ORACLE_VISION_BIN", "/definitely/missing/oracle-vision", 1)

        let result = VisionBridge.ground(imageBase64: "abc", description: "Send button")
        XCTAssertNil(result)
    }

    func testVisionBridgeParseReturnsNilWhenUnavailable() {
        setenv("ORACLE_VISION_URL", "http://127.0.0.1:9", 1)
        XCTAssertNil(VisionBridge.parse(imageBase64: "abc"))
    }

    @MainActor
    func testVisionPerceptionParseScreenFailsWhenSidecarUnavailable() {
        setenv("ORACLE_VISION_URL", "http://127.0.0.1:9", 1)

        let result = VisionPerception.parseScreen(appName: nil, fullResolution: false)
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    @MainActor
    func testVisionPerceptionGroundElementFailsWhenSidecarUnavailable() {
        setenv("ORACLE_VISION_URL", "http://127.0.0.1:9", 1)
        setenv("ORACLE_VISION_BIN", "/definitely/missing/oracle-vision", 1)

        let result = VisionPerception.groundElement(description: "Compose", appName: nil, cropBox: nil)
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    @MainActor
    func testVisionPerceptionFallbackFindReturnsNilWhenSidecarUnavailable() {
        setenv("ORACLE_VISION_URL", "http://127.0.0.1:9", 1)

        let result = VisionPerception.visionFallbackFind(query: "Compose", appName: nil)
        XCTAssertNil(result)
    }

    func testCDPBridgeGetDebugTargetsReturnsNilOnClosedPort() {
        setenv("ORACLE_CDP_PORT", "9", 1)
        XCTAssertNil(CDPBridge.getDebugTargets())
    }

    func testCDPBridgeFindElementsReturnsNilWithoutTargets() {
        setenv("ORACLE_CDP_PORT", "9", 1)
        XCTAssertNil(CDPBridge.findElements(query: "compose"))
    }
}
