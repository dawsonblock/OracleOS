import Foundation

// ─────────────────────────────────────────────────────────
// LoopBudget — per-goal step and recovery limits
//
// All budget values are hard ceilings. The loop terminates
// the moment any ceiling is hit, regardless of plan state.
// ─────────────────────────────────────────────────────────

/// Hard ceilings for a single agent loop run.
///
/// `LoopBudget` is immutable after construction. Pass it into
/// `AgentLoop.run(taskContext:budget:surface:)` at call-site.
public struct LoopBudget: Equatable {

    /// Maximum total loop steps before forced termination.
    public let maxSteps: Int

    /// Maximum total recovery attempts across all actions.
    public let maxRecoveries: Int

    /// Maximum consecutive steps spent in pure exploration
    /// (i.e. plans generated without memory or graph backing).
    public let maxConsecutiveExplorationSteps: Int

    public init(
        maxSteps: Int = 25,
        maxRecoveries: Int = 5,
        maxConsecutiveExplorationSteps: Int = 3
    ) {
        self.maxSteps = maxSteps
        self.maxRecoveries = maxRecoveries
        self.maxConsecutiveExplorationSteps = maxConsecutiveExplorationSteps
    }

    /// Conservative budget for unit tests — terminates quickly.
    public static let test = LoopBudget(maxSteps: 5, maxRecoveries: 2, maxConsecutiveExplorationSteps: 2)
}

// ─────────────────────────────────────────────────────────
// LoopBudgetState — mutable counters tracked per run
// ─────────────────────────────────────────────────────────

/// Mutable counters that the loop accumulates each step.
///
/// Pass by value so each loop step gets a fresh copy; only commit
/// the incremented state when the step completes.
public struct LoopBudgetState: Equatable {

    public private(set) var stepCount: Int = 0
    public private(set) var recoveries: Int = 0
    public private(set) var consecutiveExplorationSteps: Int = 0

    public init() {}

    // ── Mutations ───────────────────────────────────────

    /// Increment the step counter. Returns `true` when the step
    /// count equals or exceeds the budget ceiling.
    @discardableResult
    public mutating func incrementStep(budget: LoopBudget) -> Bool {
        stepCount += 1
        return stepCount >= budget.maxSteps
    }

    /// Register a recovery attempt. Returns `true` when the
    /// recovery ceiling is reached.
    @discardableResult
    public mutating func registerRecovery(budget: LoopBudget) -> Bool {
        recoveries += 1
        return recoveries >= budget.maxRecoveries
    }

    /// Register one exploration step (plan had no memory/graph backing).
    /// Returns `true` when the consecutive-exploration ceiling is hit.
    @discardableResult
    public mutating func registerExplorationStep(budget: LoopBudget) -> Bool {
        consecutiveExplorationSteps += 1
        return consecutiveExplorationSteps > budget.maxConsecutiveExplorationSteps
    }

    /// Reset the consecutive-exploration counter (call when a
    /// memory- or graph-backed step succeeds).
    public mutating func resetExploration() {
        consecutiveExplorationSteps = 0
    }

    // ── Queries ─────────────────────────────────────────

    public func canRecover(under budget: LoopBudget) -> Bool {
        recoveries < budget.maxRecoveries
    }
}
