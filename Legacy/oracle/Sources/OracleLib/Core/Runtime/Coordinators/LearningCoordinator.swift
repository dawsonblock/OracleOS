import Foundation

// ─────────────────────────────────────────────────────────
// LearningCoordinator — outcome persistence layer
//
// Records action success/failure outcomes into:
//   • MetricsRecorder — aggregated runtime performance metrics
//   • StateMemoryIndex — per-state action statistics for planning
//
// Architecture rule: does NOT plan, evaluate strategies,
// or mutate world state. All writes go through the dedicated
// recorder/index APIs only.
// ─────────────────────────────────────────────────────────

/// Records learning outcomes into metrics and state memory.
///
/// `LearningCoordinator` is a thin persistence orchestrator.
/// After each action the runtime calls `recordSuccess` or
/// `recordFailure`, then `finalize` at goal completion.
///
/// - Note: This coordinator does not plan or mutate state.
///   Planning belongs to `DecisionCoordinator`; state mutation
///   to `StateCoordinator`.
public final class LearningCoordinator {

    // ── Dependencies ────────────────────────────────────

    private let metrics: MetricsRecorder
    private let stateMemory: StateMemoryIndex

    // ── Init ────────────────────────────────────────────

    public init(
        metrics: MetricsRecorder,
        stateMemory: StateMemoryIndex
    ) {
        self.metrics = metrics
        self.stateMemory = stateMemory
    }

    // MARK: – Per-action recording

    /// Record a successful action execution.
    ///
    /// Updates `MetricsRecorder` and writes a positive outcome
    /// for the current state signature into `StateMemoryIndex`.
    public func recordSuccess(
        intent: ActionIntent,
        bundle: StateBundle,
        latencyMs: Double
    ) {
        metrics.recordAction(type: intent.type, success: true)
        metrics.recordLatency(latencyMs)

        let sig = StateSignature.from(
            context: bundle.taskContext.goal.description,
            actionTypes: [intent.type]
        )
        stateMemory.record(
            stateSignature: sig,
            actionType: intent.type,
            success: true
        )
    }

    /// Record a failed action execution.
    ///
    /// Updates `MetricsRecorder` and writes a negative outcome
    /// for the current state signature into `StateMemoryIndex`.
    public func recordFailure(
        intent: ActionIntent,
        bundle: StateBundle,
        latencyMs: Double
    ) {
        metrics.recordAction(type: intent.type, success: false)
        metrics.recordLatency(latencyMs)

        let sig = StateSignature.from(
            context: bundle.taskContext.goal.description,
            actionTypes: [intent.type]
        )
        stateMemory.record(
            stateSignature: sig,
            actionType: intent.type,
            success: false
        )
    }

    // MARK: – Recovery recording

    /// Record a recovery attempt (increments the recovery counter).
    public func recordRecovery() {
        metrics.recordRecovery()
    }

    // MARK: – Goal finalisation

    /// Record the final outcome of a completed goal.
    ///
    /// - Parameters:
    ///   - goal: The goal that completed.
    ///   - succeeded: Whether the goal was achieved successfully.
    ///   - stepCount: Number of steps taken.
    public func finalize(goal: Goal, succeeded: Bool, stepCount: Int) {
        metrics.recordGoal(success: succeeded, stepCount: stepCount)
    }
}
