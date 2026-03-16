import Foundation

// ─────────────────────────────────────────────────────────
// CoordinatorTypes — shared value types for the coordinator layer
//
// These immutable bundles are the data contract that flows
// through the coordinator stack each agent loop step.
// No coordinator mutates another coordinator's data directly.
// ─────────────────────────────────────────────────────────

// MARK: – AgentKind

/// The kind of task the agent is performing.
public enum AgentKind: String, Codable, Sendable {
    /// macOS UI interaction — AX tree, clicks, keyboard.
    case ui
    /// Code editing, builds, tests, git.
    case code
    /// Both UI and code work within the same goal.
    case mixed
}

extension AgentKind {
    /// Reference-compatibility alias for macOS/UI tasks.
    public static var os: AgentKind { .ui }
}

// MARK: – TaskContext

/// Immutable context bundle for a single agent task.
///
/// `TaskContext` travels through the coordinator stack unchanged.
/// It is the single source of truth for goal + workspace metadata
/// for a given agent session.
public struct TaskContext {

    /// The goal the agent is trying to achieve.
    public let goal: Goal

    /// Absolute path to the workspace root (nil for UI-only tasks).
    public let workspaceRoot: String?

    /// What kind of agent operations are expected.
    public let agentKind: AgentKind

    /// Unique session ID for this agent invocation.
    public let sessionID: String

    public init(
        goal: Goal,
        workspaceRoot: String? = nil,
        agentKind: AgentKind = .mixed,
        sessionID: String = UUID().uuidString
    ) {
        self.goal = goal
        self.workspaceRoot = workspaceRoot
        self.agentKind = agentKind
        self.sessionID = sessionID
    }
}

// MARK: – StateBundle

/// Per-step snapshot assembled by `StateCoordinator` for downstream use.
///
/// `StateBundle` captures the full agent context at a given loop step.
/// Coordinators downstream (Decision, Execution, Learning) consume it
/// read-only; none may mutate it.
public struct StateBundle {

    /// The task the agent is working on.
    public let taskContext: TaskContext

    /// The current world model snapshot.
    public let snapshot: WorldModelSnapshot

    /// The raw observation that produced this snapshot, if any.
    public let observation: Observation?

    /// Zero-based loop step index.
    public let stepIndex: Int

    /// ID of the last action executed (nil on first step).
    public let lastActionID: String?

    public init(
        taskContext: TaskContext,
        snapshot: WorldModelSnapshot,
        observation: Observation? = nil,
        stepIndex: Int = 0,
        lastActionID: String? = nil
    ) {
        self.taskContext = taskContext
        self.snapshot = snapshot
        self.observation = observation
        self.stepIndex = stepIndex
        self.lastActionID = lastActionID
    }
}

// MARK: – PreparedAction

/// Result of `ExecutionCoordinator.prepare(...)`:
/// a policy-gated, optionally skill-resolved intent ready for the executor.
///
/// If `policyAllowed` is false the runtime must not forward the intent
/// to `VerifiedActionExecutor`. Check `blockReason` for diagnostics.
public struct PreparedAction {

    /// The final action intent to execute.
    public let intent: ActionIntent

    /// Whether policy allows execution to proceed.
    public let policyAllowed: Bool

    /// The skill name that resolved this intent, if any.
    public let skillName: String?

    /// Resolution confidence (1.0 when not skill-resolved).
    public let confidence: Double

    /// Non-nil when `policyAllowed` is false; describes why.
    public let blockReason: String?

    public init(
        intent: ActionIntent,
        policyAllowed: Bool,
        skillName: String? = nil,
        confidence: Double = 1.0,
        blockReason: String? = nil
    ) {
        self.intent = intent
        self.policyAllowed = policyAllowed
        self.skillName = skillName
        self.confidence = confidence
        self.blockReason = blockReason
    }

    /// Convenience: true when the action is ready to execute.
    public var isReady: Bool { policyAllowed }
}
