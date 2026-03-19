import AppKit
import Foundation

@MainActor
public enum FocusManager {
    public static func focus(appName: String, windowTitle: String? = nil) -> ToolResult {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(appName) == true ||
            $0.bundleIdentifier?.localizedCaseInsensitiveContains(appName) == true
        }) else {
            return ToolResult(success: false, error: "Application '\(appName)' not found", suggestion: "Use oracle_state to see running apps")
        }

        let activated = app.activate()
        if !activated {
            return ToolResult(success: false, error: "Failed to activate '\(appName)'")
        }

        let note: String?
        if let windowTitle, !windowTitle.isEmpty {
            note = "Window focusing by title is not available in the compatibility layer"
        } else {
            note = nil
        }

        return ToolResult(success: true, data: [
            "app": app.localizedName ?? appName,
            "focused": true,
            "note": note as Any,
        ].compactMapValues { $0 })
    }

    public static func saveFrontmostApp() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    public static func restoreFocus(to app: NSRunningApplication?) {
        _ = app?.activate()
    }

    public static func withFocusRestore<T>(_ operation: () throws -> T) rethrows -> T {
        let saved = saveFrontmostApp()
        defer { restoreFocus(to: saved) }
        return try operation()
    }

    public static func clearModifierFlags() {
        if let event = CGEvent(source: nil) {
            event.type = .flagsChanged
            event.flags = CGEventFlags(rawValue: 0)
            event.post(tap: .cghidEventTap)
        }
    }
}
