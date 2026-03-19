import AppKit
import Foundation

@MainActor
public enum VisionPerception {
    public static func parseScreen(appName: String?, fullResolution: Bool) -> ToolResult {
        guard VisionBridge.isAvailable() else {
            return sidecarUnavailableResult(tool: "oracle_parse_screen")
        }
        guard let screenshot = captureForVision(appName: appName, fullResolution: fullResolution) else {
            return ToolResult(success: false, error: "Screenshot capture failed", suggestion: "Ensure Screen Recording permission is granted")
        }
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let displayWidth = Double(mainScreen?.frame.width ?? 1728)
        let displayHeight = Double(mainScreen?.frame.height ?? 1117)
        guard let result = VisionBridge.parse(imageBase64: screenshot.base64PNG, screenWidth: displayWidth, screenHeight: displayHeight) else {
            return ToolResult(success: false, error: "Vision parsing failed")
        }
        return ToolResult(success: true, data: result)
    }

    public static func groundElement(description: String, appName: String?, cropBox: [Double]?) -> ToolResult {
        guard VisionBridge.isAvailable() || VisionBridge.startSidecar() else {
            return sidecarUnavailableResult(tool: "oracle_ground")
        }
        guard let screenshot = captureForVision(appName: appName, fullResolution: false) else {
            return ToolResult(success: false, error: "Screenshot capture failed")
        }
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let displayWidth = Double(mainScreen?.frame.width ?? 1728)
        let displayHeight = Double(mainScreen?.frame.height ?? 1117)
        guard let result = VisionBridge.ground(imageBase64: screenshot.base64PNG, description: description, screenWidth: displayWidth, screenHeight: displayHeight, cropBox: cropBox) else {
            return ToolResult(success: false, error: "VLM grounding failed for '\(description)'")
        }
        return ToolResult(success: result.confidence > 0, data: [
            "x": result.x,
            "y": result.y,
            "confidence": result.confidence,
            "method": result.method,
            "description": description,
            "inference_ms": result.inferenceMs,
        ])
    }

    public static func visionFallbackFind(query: String, appName: String?) -> [[String: Any]]? {
        guard let result = visionFallbackClick(query: query, appName: appName) else { return nil }
        guard let data = result.data,
              let x = data["x"] as? Double,
              let y = data["y"] as? Double else {
            return nil
        }
        return [[
            "name": query,
            "role": "VisionGrounded",
            "position": ["x": Int(x), "y": Int(y)],
            "actionable": true,
        ]]
    }

    public static func visionFallbackClick(query: String, appName: String?) -> ToolResult? {
        let grounded = groundElement(description: query, appName: appName, cropBox: nil)
        return grounded.success ? grounded : nil
    }

    private static func captureForVision(appName: String?, fullResolution: Bool) -> ScreenshotResult? {
        let app = NSWorkspace.shared.runningApplications.first {
            guard let appName else { return false }
            return $0.localizedName?.localizedCaseInsensitiveContains(appName) == true
        } ?? NSWorkspace.shared.frontmostApplication
        guard let pid = app?.processIdentifier else { return nil }
        return ScreenCapture.captureWindowSync(pid: pid, fullResolution: fullResolution)
    }

    private static func sidecarUnavailableResult(tool: String) -> ToolResult {
        ToolResult(
            success: false,
            error: "Vision sidecar unavailable for \(tool)",
            suggestion: "Start the vision sidecar or set ORACLE_VISION_URL"
        )
    }
}
