import Foundation

// ─────────────────────────────────────────────────────────
// Actions — high-level convenience façade
//
// Each method constructs an ActionIntent and submits it
// through the CommandDispatcher. NO direct AppKit, NSWorkspace,
// or BrowserController calls.
//
// Blueprint ref: Gate 1, §1.7 — "Actions.swift uses ActionIntent"
//
// INVARIANT: This file must NOT import AppKit.
// ─────────────────────────────────────────────────────────

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

        // Focus via intent if needed
        if let appName {
            _ = focus(appName: appName, runtime: runtime, surface: surface)
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

        // Build ActionIntent and route through dispatcher
        var params: [String: String] = ["selector": selector]
        if let role { params["role"] = role }
        if let button { params["button"] = button }
        if let count { params["count"] = "\(count)" }

        let intent = ActionIntent(
            type: "browser_click",
            domain: .browser,
            parameters: params,
            sourceSurface: SourceSurface(rawValue: surface.rawValue) ?? .controller,
            approvalToken: approvalRequestID
        )

        if let runtime = runtime {
            let result = runtime.commandDispatcher.submitIntent(intent)
            return ToolResult(
                success: result.accepted,
                data: ["method": "dispatcher", "selector": selector],
                error: result.accepted ? nil : result.reason
            )
        }

        // Fallback: direct executor path for backward compatibility
        if let executor = executor {
            let result = executor.execute(action: intent)
            return toolResult(from: result, data: ["method": "executor", "selector": selector])
        }

        return ToolResult(success: false, error: "no runtime or executor available")
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
            _ = focus(appName: appName, runtime: runtime, surface: surface)
        }

        guard let selector = domId ?? into, !selector.isEmpty else {
            return ToolResult(success: false, error: "Field selector is required", suggestion: "Provide into: or domId:")
        }

        var params: [String: String] = [
            "selector": selector,
            "text": text,
            "clear": clear ? "true" : "false",
        ]

        let intent = ActionIntent(
            type: "browser_type",
            domain: .browser,
            parameters: params,
            sourceSurface: SourceSurface(rawValue: surface.rawValue) ?? .controller,
            approvalToken: approvalRequestID
        )

        if let runtime = runtime {
            let result = runtime.commandDispatcher.submitIntent(intent)
            return ToolResult(
                success: result.accepted,
                data: ["method": "dispatcher", "selector": selector],
                error: result.accepted ? nil : result.reason
            )
        }

        if let executor = executor {
            let result = executor.execute(action: intent)
            return toolResult(from: result, data: ["method": "executor", "selector": selector])
        }

        return ToolResult(success: false, error: "no runtime or executor available")
    }

    public static func focus(
        appName: String,
        windowTitle: String? = nil,
        runtime: OracleRuntime? = nil,
        surface: RuntimeSurface = .mcp
    ) -> ToolResult {
        // Delegate to FocusManager (which handles its own AppKit isolation)
        FocusManager.focus(appName: appName, windowTitle: windowTitle)
    }

    public static func openApplication(
        appName: String,
        runtime: OracleRuntime? = nil,
        surface: RuntimeSurface = .mcp
    ) -> ToolResult {

        let intent = ActionIntent(
            type: "open_application",
            domain: .system,
            parameters: ["appName": appName],
            requiresMutation: true,
            sourceSurface: SourceSurface(rawValue: surface.rawValue) ?? .controller
        )

        if let runtime = runtime {
            let result = runtime.commandDispatcher.submitIntent(intent)
            return ToolResult(
                success: result.accepted,
                data: ["app": appName],
                error: result.accepted ? nil : result.reason
            )
        }

        // Fallback: construct directly (macOS-only, but no AppKit in this file)
        return ToolResult(success: false, error: "no runtime available for open_application")
    }

    public static func navigate(
        url: String,
        runtime: OracleRuntime? = nil,
        surface: RuntimeSurface = .mcp
    ) -> ToolResult {

        let intent = ActionIntent(
            type: "browser_navigate",
            domain: .browser,
            parameters: ["url": url],
            sourceSurface: SourceSurface(rawValue: surface.rawValue) ?? .controller
        )

        if let runtime = runtime {
            let result = runtime.commandDispatcher.submitIntent(intent)
            return ToolResult(
                success: result.accepted,
                data: ["url": url],
                error: result.accepted ? nil : result.reason
            )
        }

        return ToolResult(success: false, error: "no runtime available for navigate")
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
