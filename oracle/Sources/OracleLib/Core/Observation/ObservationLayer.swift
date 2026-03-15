import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

// ─────────────────────────────────────────────────────────
// Observation Layer — Peekaboo integration point (Phase 6)
//
// Provides structured UI perception:
//   AccessibilitySnapshotService — capture AX tree
//   UIElementModel — normalized element structure
//   WindowScanner — enumerate windows
//   ApplicationScanner — enumerate running apps
//   AccessibilityActionAdapter — bridge AX actions to executor
//
// The planner never reads raw AX trees. It receives compressed
// semantic state like Button("Send"), Input("Search").
// ─────────────────────────────────────────────────────────

// ── UIElementModel ──────────────────────────────────────

public struct UIElement {

    public let id: String
    public let role: String
    public let label: String
    public let frame: CGRect
    public let actions: [String]
    public let children: [UIElement]

    public init(id: String, role: String, label: String, frame: CGRect, actions: [String], children: [UIElement]) {
        self.id = id
        self.role = role
        self.label = label
        self.frame = frame
        self.actions = actions
        self.children = children
    }

    public static let empty = UIElement(
        id: "", role: "", label: "", frame: .zero,
        actions: [], children: []
    )
}

// ── AccessibilitySnapshotService ────────────────────────

public final class AccessibilitySnapshotService {

    public init() {}

    /// Check if the process has accessibility permission.
    public func hasPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    public func captureSnapshot(appName: String) -> [UIElement] {
        print("[observation] Snapshot requested for: \(appName)")
        guard hasPermission() else {
            print("[observation] ⚠ Accessibility permission not granted")
            return []
        }

        // Find the running app by name
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: {
            $0.localizedName == appName
        }) else {
            print("[observation] App not found: \(appName)")
            return []
        }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        return captureChildren(of: axApp, depth: 0, maxDepth: 5)
    }

    public func captureActiveWindow() -> [UIElement] {
        guard hasPermission() else { return [] }

        let workspace = NSWorkspace.shared
        guard let app = workspace.frontmostApplication else { return [] }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        // Get focused window
        var windowRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard result == .success, let window = windowRef else { return [] }

        // We have the window as AXUIElement, safe to cast
        let axWindow = window as! AXUIElement
        return captureChildren(of: axWindow, depth: 0, maxDepth: 4)
    }

    // ── Private AX tree walker ───────────────────────

    private func captureChildren(of element: AXUIElement, depth: Int, maxDepth: Int) -> [UIElement] {
        guard depth < maxDepth else { return [] }

        var childrenRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        guard result == .success, let children = childrenRef as? [AXUIElement] else { return [] }

        return children.compactMap { child -> UIElement? in
            // Role
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? "unknown"

            // Title/label
            var titleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""

            var descRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef)
            let desc = descRef as? String ?? ""

            let label = title.isEmpty ? desc : title

            // Position + size
            var posRef: AnyObject?
            var sizeRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef)

            var point = CGPoint.zero
            var size = CGSize.zero
            if let posValue = posRef { AXValueGetValue(posValue as! AXValue, .cgPoint, &point) }
            if let sizeValue = sizeRef { AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) }
            let frame = CGRect(origin: point, size: size)

            // Actions
            var actionsRef: CFArray?
            AXUIElementCopyActionNames(child, &actionsRef)
            let actions = (actionsRef as? [String]) ?? []

            // Recurse children
            let subChildren = captureChildren(of: child, depth: depth + 1, maxDepth: maxDepth)

            return UIElement(
                id: "\(role)-\(label.prefix(20))",
                role: role,
                label: label,
                frame: frame,
                actions: actions,
                children: subChildren
            )
        }
    }
}

// ── WindowScanner ───────────────────────────────────────

public struct WindowInfo {

    public let id: Int
    public let title: String
    public let appName: String
    public let frame: CGRect
    public let isActive: Bool
}

public final class WindowScanner {

    public init() {}

    public func scanWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return windowList.compactMap { info in
            guard let id = info[kCGWindowNumber as String] as? Int,
                  let name = info[kCGWindowOwnerName as String] as? String else { return nil }
            let title = info[kCGWindowName as String] as? String ?? ""
            let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let frame = CGRect(
                x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0
            )
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            return WindowInfo(id: id, title: title, appName: name, frame: frame, isActive: layer == 0)
        }
    }

    public func activeWindow() -> WindowInfo? {
        return scanWindows().first { $0.isActive }
    }
}

// ── ApplicationScanner ──────────────────────────────────

public struct AppInfo {

    public let name: String
    public let bundleID: String
    public let isActive: Bool
    public let pid: Int32
}

public final class ApplicationScanner {

    public init() {}

    public func runningApps() -> [AppInfo] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { app in
                AppInfo(
                    name: app.localizedName ?? "unknown",
                    bundleID: app.bundleIdentifier ?? "",
                    isActive: app.isActive,
                    pid: app.processIdentifier
                )
            }
    }

    public func activeApp() -> AppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AppInfo(
            name: app.localizedName ?? "unknown",
            bundleID: app.bundleIdentifier ?? "",
            isActive: true,
            pid: app.processIdentifier
        )
    }
}

// ── AccessibilityActionAdapter ──────────────────────────

public final class AccessibilityActionAdapter {

    public init() {}

    public func click(element: UIElement) -> ExecutionResult {
        // Phase 6: perform AX click, return through executor
        return ExecutionResult(success: false, detail: "observation not yet wired")
    }

    public func type(element: UIElement, text: String) -> ExecutionResult {
        return ExecutionResult(success: false, detail: "observation not yet wired")
    }

    public func focus(element: UIElement) -> ExecutionResult {
        return ExecutionResult(success: false, detail: "observation not yet wired")
    }
}
