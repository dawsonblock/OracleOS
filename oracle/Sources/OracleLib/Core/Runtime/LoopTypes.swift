import Foundation

// ─────────────────────────────────────────────────────────
// LoopTypes — termination reasons and outcome record
//
// Every AgentLoop run ends with a LoopOutcome. The runtime
// stores outcomes for diagnostics, metrics, and regression
// baseline comparison.
// ─────────────────────────────────────────────────────────

// MARK: – LoopTerminationReason

/// Why the agent loop stopped.
public enum LoopTerminationReason: String, Equatable {
    /// Agent reached the goal successfully.
    case goalAchieved
    /// Step ceiling hit before goal was reached.
    case maxSteps
    /// Policy denied a required action.
    case policyBlocked
    /// No viable plan could be generated.
    case noViablePlan
    /// Failure could not be recovered within the recovery budget.
    case unrecoverableFailure
    /// Consecutive exploration steps exceeded the budget.
    case explorationBudgetExceeded
    /// Recovery budget exhausted.
    case recoveryBudgetExhausted
}

// MARK: – LoopOutcome

/// Complete record of a single `AgentLoop` run.
///
/// `LoopOutcome` is produced at loop exit regardless of whether
/// the goal was achieved. Store it in `MetricsRecorder` or
/// `TraceReplayEngine` for trend analysis and regression detection.
public struct LoopOutcome: Equatable {

    /// Why the loop terminated.
    public let reason: LoopTerminationReason

    /// World snapshot at the moment of termination.
    public let finalSnapshot: WorldModelSnapshot

    /// Total loop steps executed (0-based count).
    public let steps: Int

    /// Total recovery attempts during the run.
    public let recoveries: Int

    /// Human-readable summary for logs.
    public var summary: String {
        "[\(reason.rawValue)] steps=\(steps) recoveries=\(recoveries) app=\(finalSnapshot.activeApplication ?? "none")"
    }

    public init(
        reason: LoopTerminationReason,
        finalSnapshot: WorldModelSnapshot,
        steps: Int,
        recoveries: Int
    ) {
        self.reason = reason
        self.finalSnapshot = finalSnapshot
        self.steps = steps
        self.recoveries = recoveries
    }
}
