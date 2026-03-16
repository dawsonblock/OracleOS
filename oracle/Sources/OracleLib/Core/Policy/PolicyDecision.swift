import Foundation

// ─────────────────────────────────────────────────────────
// PolicyDecision — typed authorization result
//
// Replaces the bare Bool return from PolicyEngine.allow().
// Every policy evaluation now carries structured reasoning
// consumable by the executor, trace recorder, and recovery
// systems.
//
// Blueprint ref: Gate 1, §1.2
// ─────────────────────────────────────────────────────────

/// Machine-readable outcome of a policy evaluation.
public struct PolicyDecision: Sendable, Equatable {

    // MARK: – Fields

    /// Whether the action is authorized for execution.
    public let allowed: Bool

    /// If true, a controller-level approval token is required before execution.
    public let requiresApproval: Bool

    /// If true, the action must be routed to a sandboxed environment.
    public let requiresSandbox: Bool

    /// Human-readable explanation of the decision.
    public let reason: String

    /// Machine-readable code for programmatic branching.
    public let decisionCode: DecisionCode

    /// The risk level evaluated for this action.
    public let riskLevel: RiskLevel

    // MARK: – Init

    public init(
        allowed: Bool,
        requiresApproval: Bool = false,
        requiresSandbox: Bool = false,
        reason: String,
        decisionCode: DecisionCode = .allowed,
        riskLevel: RiskLevel = .safe
    ) {
        self.allowed = allowed
        self.requiresApproval = requiresApproval
        self.requiresSandbox = requiresSandbox
        self.reason = reason
        self.decisionCode = decisionCode
        self.riskLevel = riskLevel
    }

    // MARK: – Decision codes

    /// Categorized outcome for branching logic.
    public enum DecisionCode: String, Sendable, Equatable {
        /// Action is fully authorized.
        case allowed
        /// Blocked by an explicit deny rule.
        case blocked
        /// Blocked because the domain is not in the capability allowlist.
        case domainDisabled
        /// Blocked — approval required but not provided.
        case approvalRequired
        /// Allowed — but must execute in sandbox.
        case sandboxRequired
        /// Blocked — target path is outside the workspace boundary.
        case outsideWorkspace
        /// Blocked — free-form shell string rejected.
        case unsafeShellCommand
    }

    // MARK: – Factories

    /// Convenience: fully authorized, no constraints.
    public static func allow(reason: String = "policy passed", riskLevel: RiskLevel = .safe) -> PolicyDecision {
        PolicyDecision(
            allowed: true,
            reason: reason,
            decisionCode: .allowed,
            riskLevel: riskLevel
        )
    }

    /// Convenience: blocked with a specific code.
    public static func deny(reason: String, code: DecisionCode = .blocked) -> PolicyDecision {
        PolicyDecision(
            allowed: false,
            reason: reason,
            decisionCode: code
        )
    }

    /// Convenience: allowed but sandbox-routed.
    public static func sandbox(reason: String, riskLevel: RiskLevel = .elevated) -> PolicyDecision {
        PolicyDecision(
            allowed: true,
            requiresSandbox: true,
            reason: reason,
            decisionCode: .sandboxRequired,
            riskLevel: riskLevel
        )
    }

    /// Convenience: blocked pending approval.
    public static func pendingApproval(reason: String) -> PolicyDecision {
        PolicyDecision(
            allowed: false,
            requiresApproval: true,
            reason: reason,
            decisionCode: .approvalRequired
        )
    }
}
