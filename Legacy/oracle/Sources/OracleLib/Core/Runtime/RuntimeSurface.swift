import Foundation

// ─────────────────────────────────────────────────────────
// RuntimeSurface — the entry surface that triggered the agent
//
// The surface informs policy about trust level and approval
// requirements. More interactive surfaces (controller, CLI)
// receive stricter approval thresholds.
// ─────────────────────────────────────────────────────────

/// Entry point that invoked the agent loop.
public enum RuntimeSurface: String, Equatable, Hashable, Sendable {
    /// macOS controller app — highest trust (user is present).
    case controller
    /// Model Context Protocol invocation.
    case mcp
    /// Command-line invocation.
    case cli
    /// Recipe / automation macro trigger.
    case recipe
}
