import Foundation

// ─────────────────────────────────────────────────────────
// ExecutionState — runtime-wide state snapshot
//
// Read-only snapshot for diagnostics and planner context.
// The planner reads ONLY committed state, never raw
// observation data.
// ─────────────────────────────────────────────────────────

public struct ExecutionState {

    public let activeGoal: Goal?
    public let activePlan: Plan?
    public let lastResult: ExecutionResult?
    public let actionCount: Int
    public let failureCount: Int
    public let uptime: TimeInterval

    public static let empty = ExecutionState(
        activeGoal: nil,
        activePlan: nil,
        lastResult: nil,
        actionCount: 0,
        failureCount: 0,
        uptime: 0
    )
}
