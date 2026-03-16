import AppKit
import Foundation

@MainActor
public enum Actions {
    public static func click(
        query: String?,
        role: String?,
        domId: String?,
        appName: String?,
        x: Double?,
        y: Double?,
        button: String?,
        count: Int?,
        executor: VerifiedActionExecutor? = nil,
        runtime: OracleRuntime? = nil,
        surface: RuntimeSurface = .mcp,
        approvalRequestID: String? = nil,
        taskID: String? = nil,
        toolName: String? = "oracle_click"
    ) -> ToolResult {
        if let appName {
            _ = FocusManager.focus(appName: appName)
        }

        if let x, let y {
            return ToolResult(
                success: false,
                error: "Coordinate click is not implemented in the compatibility layer",
                suggestion: "Use a DOM selector or query instead",
                context: ContextInfo(app: appName, focusedElement: "(\(Int(x)), \(Int(y)))")
            )
        }

        let selector = domId ?? query
        guard let selector, !selector.isEmpty else {
            return ToolResult(success: false, error: "Either query/dom_id or x/y coordinates required")
        }

        let controller = BrowserController()
        let result = controller.click(selector: selector)
        return toolResult(from: result, data: [
            "method": "browser-controller",
            "selector": selector,
            "role": role as Any,
            "button": button as Any,
            "count": count as Any,
        ])
    }

    public static func typeText(
        text: String,
        into: String?,
        domId: String?,
        appName: String?,
        clear: Bool,
        executor: VerifiedActionExecutor? = nil,
        runtime: OracleRuntime? = nil,
        surface: RuntimeSurface = .mcp,
        approvalRequestID: String? = nil,
        taskID: String? = nil,
        toolName: String? = "oracle_type"
    ) -> ToolResult {
        if let appName {
            _ = FocusManager.focus(appName: appName)
        }
        guard let selector = domId ?? into, !selector.isEmpty else {
            return ToolResult(success: false, error: "Field selector is required", suggestion: "Provide into: or domId:")
        }
        let controller = BrowserController()
        let result = controller.type(selector: selector, text: clear ? text : text)
        return toolResult(from: result, data: [
            "method": "browser-controller",
            "selector": selector,
            "clear": clear,
        ])
    }

    public static func focus(appName: String, windowTitle: String? = nil) -> ToolResult {
        FocusManager.focus(appName: appName, windowTitle: windowTitle)
    }

    public static func openApplication(appName: String) -> ToolResult {
        if let existing = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(appName) == true
        }) {
            _ = existing.activate()
            return ToolResult(success: true, data: ["app": existing.localizedName ?? appName, "focused": true])
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
            return ToolResult(success: true, data: ["app": appName, "launched": true])
        }

        return ToolResult(success: false, error: "Application '\(appName)' not found")
    }

    public static func navigate(url: String) -> ToolResult {
        let controller = BrowserController()
        let result = controller.navigate(url: url)
        return toolResult(from: result, data: ["url": url])
    }

    private static func toolResult(from result: ExecutionResult, data: [String: Any]? = nil) -> ToolResult {
        ToolResult(
            success: result.success,
            data: data,
            error: result.success ? nil : result.detail,
            context: nil
        )
    }
}
