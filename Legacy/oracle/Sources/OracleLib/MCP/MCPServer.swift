import Foundation

// ─────────────────────────────────────────────────────────
// MCPServer — Model Context Protocol surface
//
// Exposes Oracle capabilities through 22 stable oracle_* tools.
// External clients connect here; all calls route through
// the standard execution pipeline.
// ─────────────────────────────────────────────────────────

public final class MCPServer {

    private let toolRegistry: MCPToolRegistry
    private var isRunning = false

    public init(toolRegistry: MCPToolRegistry = MCPToolRegistry()) {
        self.toolRegistry = toolRegistry
    }

    public func start(port: Int = 9222) {
        toolRegistry.registerDefaults()
        isRunning = true
        print("[mcp] Server started on port \(port) with \(toolRegistry.toolCount()) tools")
    }

    public func stop() {
        isRunning = false
        print("[mcp] Server stopped")
    }

    public func toolCount() -> Int {
        return toolRegistry.toolCount()
    }

    public func allToolDefinitions() -> [MCPToolDefinition] {
        return toolRegistry.allTools()
    }

    public func handleRequest(toolName: String, parameters: [String: String]) -> MCPResponse {

        guard isRunning else {
            return MCPResponse(success: false, data: "MCP server not running")
        }

        guard let tool = toolRegistry.tool(named: toolName) else {
            return MCPResponse(success: false, data: "unknown tool: \(toolName)")
        }

        // Route through standard action pipeline
        let intent = ActionIntent(
            type: tool.actionType,
            domain: tool.domain,
            parameters: parameters
        )

        // The caller (OracleRuntime) will route this through
        // policy → executor → trace. MCP never bypasses.
        return MCPResponse(
            success: true,
            data: "routed to executor: \(intent.type)",
            actionIntent: intent
        )
    }
}

// ─────────────────────────────────────────────────────────
// MCPResponse
// ─────────────────────────────────────────────────────────

public struct MCPResponse {
    public let success: Bool
    public let data: String
    public let actionIntent: ActionIntent?

    public init(success: Bool, data: String, actionIntent: ActionIntent? = nil) {
        self.success = success
        self.data = data
        self.actionIntent = actionIntent
    }
}

// ─────────────────────────────────────────────────────────
// MCPToolRegistry — declares available MCP tools
// ─────────────────────────────────────────────────────────

public struct MCPToolDefinition {
    public let name: String        // e.g. "oracle_click"
    public let actionType: String  // maps to ActionRegistry type
    public let domain: ActionDomain
    public let description: String

    public init(name: String, actionType: String, domain: ActionDomain, description: String) {
        self.name = name
        self.actionType = actionType
        self.domain = domain
        self.description = description
    }
}

public final class MCPToolRegistry {

    private var tools: [String: MCPToolDefinition] = [:]

    public init() {}

    public func register(_ tool: MCPToolDefinition) {
        tools[tool.name] = tool
    }

    public func tool(named name: String) -> MCPToolDefinition? {
        return tools[name]
    }

    public func toolCount() -> Int {
        return tools.count
    }

    public func allTools() -> [MCPToolDefinition] {
        return Array(tools.values).sorted { $0.name < $1.name }
    }

    public func registerDefaults() {

        // Perception tools
        register(MCPToolDefinition(name: "oracle_context", actionType: "get_context", domain: .host, description: "Get current app context"))
        register(MCPToolDefinition(name: "oracle_state", actionType: "get_state", domain: .host, description: "Get UI state snapshot"))
        register(MCPToolDefinition(name: "oracle_find", actionType: "find_element", domain: .host, description: "Find UI element"))
        register(MCPToolDefinition(name: "oracle_read", actionType: "read_element", domain: .host, description: "Read element text"))
        register(MCPToolDefinition(name: "oracle_inspect", actionType: "inspect_element", domain: .host, description: "Inspect element details"))
        register(MCPToolDefinition(name: "oracle_screenshot", actionType: "screenshot", domain: .host, description: "Capture screenshot"))

        // Action tools
        register(MCPToolDefinition(name: "oracle_click", actionType: "click_element", domain: .host, description: "Click element"))
        register(MCPToolDefinition(name: "oracle_type", actionType: "type_text", domain: .host, description: "Type text"))
        register(MCPToolDefinition(name: "oracle_press", actionType: "press_key", domain: .host, description: "Press key"))
        register(MCPToolDefinition(name: "oracle_hotkey", actionType: "hotkey", domain: .host, description: "Press hotkey combo"))
        register(MCPToolDefinition(name: "oracle_scroll", actionType: "scroll", domain: .host, description: "Scroll element"))
        register(MCPToolDefinition(name: "oracle_focus", actionType: "focus_app", domain: .host, description: "Focus application"))
        register(MCPToolDefinition(name: "oracle_window", actionType: "manage_window", domain: .host, description: "Manage window"))

        // Wait / diagnostics
        register(MCPToolDefinition(name: "oracle_wait", actionType: "wait_condition", domain: .system, description: "Wait for condition"))
        register(MCPToolDefinition(name: "oracle_doctor", actionType: "doctor", domain: .system, description: "System health check"))

        // Search
        register(MCPToolDefinition(name: "oracle_search", actionType: "web_search", domain: .search, description: "Search the web"))

        print("[mcp] Registered \(toolCount()) tools")
    }
}

// ─────────────────────────────────────────────────────────
// ContextBridge — connect MCP to Oracle context pipeline
// ─────────────────────────────────────────────────────────

public final class ContextBridge {

    public init() {}

    public func provideContext(for toolName: String, memory: GraphStore) -> [String: String] {
        // Phase 16+: assemble relevant context for the MCP client
        return ["tool": toolName, "status": "context bridge stub"]
    }
}
