import AppKit
import Foundation

// MARK: - ToolResult

/// Generic result envelope for optional vision tools.
public struct ToolResult: Sendable {
    public let success: Bool
    public let data: [String: String]
    public let error: String?
    public let suggestion: String?

    public init(
        success: Bool,
        data: [String: String] = [:],
        error: String? = nil,
        suggestion: String? = nil
    ) {
        self.success = success
        self.data = data
        self.error = error
        self.suggestion = suggestion
    }
}

// MARK: - VisionPerception

/// Experimental vision-backed helpers for parsing and grounding screen regions.
@MainActor
public enum VisionPerception {
    private static let logger = ExecutionLogger()

    public static func parseScreen(
        appName: String?,
        fullResolution: Bool = false
    ) -> ToolResult {
        guard VisionBridge.isAvailable() else {
            return sidecarUnavailableResult(tool: "oracle_parse_screen")
        }

        guard let screenshot = captureForVision(appName: appName, fullResolution: fullResolution) else {
            return ToolResult(
                success: false,
                error: "Screenshot capture failed",
                suggestion: "Ensure Screen Recording permission is granted"
            )
        }

        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let width = Double(mainScreen?.frame.width ?? 1728)
        let height = Double(mainScreen?.frame.height ?? 1117)

        guard let result = VisionBridge.parse(
            imageBase64: screenshot.base64PNG,
            screenWidth: width,
            screenHeight: height
        ) else {
            return ToolResult(
                success: false,
                error: "Vision parsing failed",
                suggestion: "The vision sidecar may have crashed or returned an invalid response"
            )
        }

        return ToolResult(success: true, data: stringify(result), suggestion: "Screen parsed successfully")
    }

    public static func groundElement(
        description: String,
        appName: String?,
        cropBox: [Double]? = nil
    ) -> ToolResult {
        if !VisionBridge.isAvailable() && !VisionBridge.startSidecar() {
            return sidecarUnavailableResult(tool: "oracle_ground")
        }

        guard let screenshot = captureForVision(appName: appName, fullResolution: false) else {
            return ToolResult(
                success: false,
                error: "Screenshot capture failed",
                suggestion: "Ensure Screen Recording permission is granted"
            )
        }

        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let displayWidth = Double(mainScreen?.frame.width ?? 1728)
        let displayHeight = Double(mainScreen?.frame.height ?? 1117)
        let isFullscreen = screenshot.windowWidth > 0 && (screenshot.windowWidth / displayWidth) > 0.9

        let sidecarWidth = isFullscreen ? displayWidth : max(screenshot.windowWidth, Double(screenshot.width))
        let sidecarHeight = isFullscreen ? displayHeight : max(screenshot.windowHeight, Double(screenshot.height))
        let offsetX = isFullscreen ? 0 : screenshot.windowX
        let offsetY = isFullscreen ? 0 : screenshot.windowY

        guard let result = VisionBridge.ground(
            imageBase64: screenshot.base64PNG,
            description: description,
            screenWidth: sidecarWidth,
            screenHeight: sidecarHeight,
            cropBox: cropBox
        ) else {
            return ToolResult(
                success: false,
                error: "VLM grounding failed for '\(description)'",
                suggestion: "The vision sidecar may have crashed. Check its logs or restart it."
            )
        }

        let mappedX = result.x + offsetX
        let mappedY = result.y + offsetY
        logger.log("Vision grounded '\(description)' at (\(Int(mappedX)), \(Int(mappedY)))", level: .info)

        var data: [String: String] = [
            "x": String(mappedX),
            "y": String(mappedY),
            "confidence": String(result.confidence),
            "method": result.method,
            "description": description,
            "inference_ms": String(result.inferenceMs),
        ]
        if let cropBox, cropBox.count == 4 {
            data["crop_box"] = cropBox.map { String($0) }.joined(separator: ",")
        }

        let suggestion: String?
        if result.confidence < 0.3 {
            suggestion = "Low confidence. Verify the target is visible before clicking."
        } else if result.confidence < 0.6 {
            suggestion = "Medium confidence. A crop box may improve grounding accuracy."
        } else {
            suggestion = nil
        }

        return ToolResult(success: result.confidence > 0, data: data, suggestion: suggestion)
    }

    public static func visionFallbackFind(
        query: String,
        appName: String?
    ) -> [[String: Any]]? {
        guard VisionBridge.isAvailable() else { return nil }
        let grounded = groundElement(description: query, appName: appName, cropBox: nil)
        guard grounded.success,
              let x = grounded.data["x"],
              let y = grounded.data["y"] else {
            return nil
        }

        return [[
            "label": query,
            "x": x,
            "y": y,
            "source": "vision",
            "confidence": grounded.data["confidence"] ?? "0",
        ]]
    }

    private static func sidecarUnavailableResult(tool: String) -> ToolResult {
        ToolResult(
            success: false,
            error: "Vision sidecar unavailable for \(tool)",
            suggestion: "Start the vision sidecar or configure ORACLE_VISION_URL."
        )
    }

    private static func captureForVision(appName: String?, fullResolution: Bool) -> ScreenshotResult? {
        guard let pid = resolvePID(appName: appName) else { return nil }
        return ScreenCapture.captureWindowSync(pid: pid, fullResolution: fullResolution)
    }

    private static func resolvePID(appName: String?) -> pid_t? {
        if let appName,
           let app = NSWorkspace.shared.runningApplications.first(where: {
               $0.localizedName?.caseInsensitiveCompare(appName) == .orderedSame
           }) {
            return app.processIdentifier
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    private static func stringify(_ dictionary: [String: Any]) -> [String: String] {
        dictionary.reduce(into: [:]) { partialResult, pair in
            switch pair.value {
            case let string as String:
                partialResult[pair.key] = string
            case let number as NSNumber:
                partialResult[pair.key] = number.stringValue
            default:
                partialResult[pair.key] = String(describing: pair.value)
            }
        }
    }
}
