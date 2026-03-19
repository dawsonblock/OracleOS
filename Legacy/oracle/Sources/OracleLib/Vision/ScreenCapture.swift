import AppKit
import CoreGraphics
import Foundation

public enum ScreenCapture {
    public static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    public enum CaptureFailure: Sendable, Equatable {
        case noPermission
        case noWindowsForApp
        case captureReturnedNil
    }

    public static func captureWindowSync(pid: pid_t, fullResolution: Bool = false) -> ScreenshotResult? {
        let (result, _) = captureWindowSyncWithReason(pid: pid, fullResolution: fullResolution)
        return result
    }

    public static func captureWindowSyncWithReason(pid: pid_t, fullResolution: Bool = false) -> (ScreenshotResult?, CaptureFailure?) {
        guard hasPermission() else { return (nil, .noPermission) }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier == pid }
        guard !apps.isEmpty else { return (nil, .noWindowsForApp) }
        return (nil, .captureReturnedNil)
    }
}
