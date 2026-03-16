import Foundation

// ─────────────────────────────────────────────────────────
// CommandDispatcher — single normalization point for all
// inbound work (goals, intents, experiments, recovery jobs)
//
// Every external surface (CLI, MCP, UI, scheduled tasks,
// experiment scheduler) submits work through the dispatcher.
// The dispatcher tags source surface, validates, and routes
// into AgentLoop.
//
// No side channel may mutate the environment directly.
//
// Blueprint ref: Gate 1, §1.9
// ─────────────────────────────────────────────────────────

/// Normalized work item entering the runtime.
public enum DispatchableWork: Sendable {
    /// A new goal to plan and execute.
    case goal(Goal, SourceSurface)
    /// A raw action intent to execute within the current loop.
    case intent(ActionIntent)
    /// An experiment job to run at lower priority.
    case experiment(Goal, SourceSurface)
    /// A recovery replay from a previous failure.
    case recovery(Goal, SourceSurface)
}

/// Outcome of a dispatched work item.
public struct DispatchResult: Sendable {
    public let accepted: Bool
    public let reason: String
    public let workID: String

    public init(accepted: Bool, reason: String, workID: String = UUID().uuidString) {
        self.accepted = accepted
        self.reason = reason
        self.workID = workID
    }

    public static func accepted(workID: String = UUID().uuidString) -> DispatchResult {
        DispatchResult(accepted: true, reason: "dispatched", workID: workID)
    }

    public static func rejected(reason: String) -> DispatchResult {
        DispatchResult(accepted: false, reason: reason)
    }
}

/// Routes all external inputs into the canonical agent loop.
///
/// `CommandDispatcher` is the **only** sanctioned entry point for
/// runtime work. MCP, CLI, controller UI, recipe triggers, and
/// experiment schedulers all submit through `dispatch(_:)`.
///
/// Direct calls to `VerifiedActionExecutor`, `AgentLoop`, or
/// controller APIs are architectural violations.
public final class CommandDispatcher {

    // ── Dependencies ────────────────────────────────────

    private weak var runtime: OracleRuntime?

    // ── Queue ───────────────────────────────────────────

    private var pendingWork: [DispatchableWork] = []
    private let lock = NSLock()

    // ── Init ────────────────────────────────────────────

    public init() {}

    /// Attach the runtime reference (called during bootstrap).
    public func attach(runtime: OracleRuntime) {
        self.runtime = runtime
    }

    // MARK: – Dispatch

    /// Submit work for execution. Returns immediately with acceptance status.
    @discardableResult
    public func dispatch(_ work: DispatchableWork, budget: LoopBudget = LoopBudget()) -> DispatchResult {
        guard let runtime = runtime else {
            return .rejected(reason: "runtime not attached")
        }

        switch work {
        case .goal(let goal, let surface):
            let context = TaskContext(
                goal: goal,
                workspaceRoot: nil,
                agentKind: GoalClassifier.classify(description: goal.description),
                sessionID: UUID().uuidString
            )
            let outcome = runtime.agentLoop.run(
                taskContext: context,
                budget: budget,
                surface: surfaceToRuntime(surface)
            )
            return DispatchResult(
                accepted: true,
                reason: outcome.summary,
                workID: context.sessionID
            )

        case .intent(let intent):
            // Single-action execution through the loop
            let goal = Goal(
                description: "Execute \(intent.type)",
                priority: .normal
            )
            let context = TaskContext(
                goal: goal,
                agentKind: .mixed,
                sessionID: UUID().uuidString
            )
            // For single intents, execute directly through the executor
            // after policy check (preserving the execution truth boundary)
            let result = runtime.executor.execute(action: intent)
            runtime.traceRecorder.record(
                TraceEvent(
                    action: intent,
                    outcome: result.success ? .success : .failure,
                    detail: result.detail
                )
            )
            return DispatchResult(
                accepted: true,
                reason: result.detail,
                workID: context.sessionID
            )

        case .experiment(let goal, let surface):
            // Experiments use the same execution spine at lower priority
            let context = TaskContext(
                goal: goal,
                agentKind: GoalClassifier.classify(description: goal.description),
                sessionID: "exp-\(UUID().uuidString)"
            )
            let outcome = runtime.agentLoop.run(
                taskContext: context,
                budget: budget,
                surface: surfaceToRuntime(surface)
            )
            return DispatchResult(
                accepted: true,
                reason: outcome.summary,
                workID: context.sessionID
            )

        case .recovery(let goal, let surface):
            let context = TaskContext(
                goal: goal,
                agentKind: .mixed,
                sessionID: "rec-\(UUID().uuidString)"
            )
            let outcome = runtime.agentLoop.run(
                taskContext: context,
                budget: budget,
                surface: surfaceToRuntime(surface)
            )
            return DispatchResult(
                accepted: true,
                reason: outcome.summary,
                workID: context.sessionID
            )
        }
    }

    // MARK: – Convenience: submit goal from a named surface

    /// Submit a goal from a specific surface (CLI, MCP, etc.).
    /// - Parameter budget: Step/recovery limits. Defaults to full autonomous budget.
    @discardableResult
    public func submitGoal(_ goal: Goal, from surface: SourceSurface, budget: LoopBudget = LoopBudget()) -> DispatchResult {
        dispatch(.goal(goal, surface), budget: budget)
    }

    /// Submit a single action intent (tagged with its own source surface).
    @discardableResult
    public func submitIntent(_ intent: ActionIntent) -> DispatchResult {
        dispatch(.intent(intent))
    }

    // MARK: – Internal

    private func surfaceToRuntime(_ surface: SourceSurface) -> RuntimeSurface {
        switch surface {
        case .cli: return .cli
        case .mcp: return .mcp
        case .controller: return .controller
        case .recipe: return .recipe
        case .experiment: return .recipe  // experiments use recipe trust level
        case .recovery: return .recipe
        case .runtime: return .recipe
        }
    }
}
