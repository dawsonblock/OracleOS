import Foundation

// ─────────────────────────────────────────────────────────
// ActionIntent — the unit of work the executor processes
//
// Every world-changing action is represented as an intent.
// Intents carry typed parameters, a domain tag for routing,
// a source surface for policy trust evaluation, and a
// mutation flag for verification gating.
//
// Blueprint ref: Gate 1, §1.1
// ─────────────────────────────────────────────────────────

public enum ActionDomain: String, Sendable {
    case system     // internal runtime ops
    case host       // macOS UI control
    case browser    // web automation
    case code       // code editing, builds, tests
    case search     // web search, discovery
    case tool       // registered tools (git, shell, etc.)
}

/// The entry surface that created this intent.
///
/// Policy uses `sourceSurface` to vary trust levels — e.g. MCP
/// requests may face stricter sandbox requirements than CLI.
public enum SourceSurface: String, Sendable, Equatable {
    /// Command-line invocation.
    case cli
    /// Model Context Protocol (remote agent).
    case mcp
    /// macOS controller UI.
    case controller
    /// Recipe / automation macro.
    case recipe
    /// Background experiment.
    case experiment
    /// Recovery subsystem retry.
    case recovery
    /// Internal runtime (planner-generated).
    case runtime
}

public struct ActionIntent: Sendable {

    public let id: String
    public let type: String
    public let domain: ActionDomain
    public let parameters: [String: String]
    public let createdAt: Date

    /// Whether this action mutates the environment. Read-only actions
    /// skip postcondition verification.
    public let requiresMutation: Bool

    /// Optional scoped target (e.g. file path, URL, app bundle ID)
    /// used by policy to evaluate workspace-boundary constraints.
    public let targetScope: String?

    /// Which surface created this intent — drives policy trust level.
    public let sourceSurface: SourceSurface

    /// Optional approval token for actions requiring explicit approval.
    public let approvalToken: String?

    public init(
        type: String,
        domain: ActionDomain = .system,
        parameters: [String: String] = [:],
        id: String = UUID().uuidString,
        requiresMutation: Bool = false,
        targetScope: String? = nil,
        sourceSurface: SourceSurface = .runtime,
        approvalToken: String? = nil
    ) {
        self.id = id
        self.type = type
        self.domain = domain
        self.parameters = parameters
        self.createdAt = Date()
        self.requiresMutation = requiresMutation
        self.targetScope = targetScope
        self.sourceSurface = sourceSurface
        self.approvalToken = approvalToken
    }
}
