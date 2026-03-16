import Foundation

// ─────────────────────────────────────────────────────────
// AgentLoop — integrated control loop
//
// `AgentLoop` is the canonical execution spine for a single
// goal. It orchestrates the four coordinators, the executor,
// the critic, and recovery into the required sequence:
//
//   observe → decide → prepare → execute → evaluate →
//   learn  → recover (on failure) → repeat
//
// Architecture rule (ARCHITECTURE_RULES.md):
//   R4 — Skills resolve intent only; AgentLoop is the
//   only component that calls VerifiedActionExecutor.
//
// Required execution sequence (ARCHITECTURE_RULES.md):
//   planner proposes → policy authorises → executor acts →
//   verifier judges → runtime commits → trace records →
//   recovery reacts
// ─────────────────────────────────────────────────────────

/// Drives the observe-decide-execute-evaluate-learn cycle for one goal.
///
/// Callers construct `AgentLoop` from an `OracleRuntime` and then call
/// `run(taskContext:budget:surface:)`. The loop is synchronous — wrap in
/// a `Task` or background thread when needed.
///
/// ```swift
/// let loop = AgentLoop(runtime: runtime)
/// let outcome = loop.run(
///     taskContext: TaskContext(goal: goal, workspaceRoot: "/workspace"),
///     budget: .init(maxSteps: 10)
/// )
/// ```
public final class AgentLoop {

    // ── Runtime reference ───────────────────────────────

    private let runtime: OracleRuntime

    // ── Coordinator aliases (for readability) ───────────

    private var stateCoord:     StateCoordinator     { runtime.stateCoordinator }
    private var decisionCoord:  DecisionCoordinator  { runtime.decisionCoordinator }
    private var executionCoord: ExecutionCoordinator { runtime.executionCoordinator }
    private var learningCoord:  LearningCoordinator  { runtime.learningCoordinator }
    private var executor:       VerifiedActionExecutor { runtime.executor }
    private var critic:         CriticLoop           { runtime.critic }
    private var recovery:       RecoveryCoordinator  { runtime.recovery }

    // ── Init ────────────────────────────────────────────

    public init(runtime: OracleRuntime) {
        self.runtime = runtime
    }

    // MARK: – Run

    /// Execute the agent loop for the given task context.
    ///
    /// - Parameters:
    ///   - taskContext: Immutable goal + workspace metadata.
    ///   - budget: Hard limits on steps and recoveries.
    ///   - surface: The entry surface (affects policy trust level).
    /// - Returns: A `LoopOutcome` describing why the loop ended.
    @discardableResult
    public func run(
        taskContext: TaskContext,
        budget: LoopBudget = LoopBudget(),
        surface: RuntimeSurface = .recipe
    ) -> LoopOutcome {

        var budgetState = LoopBudgetState()
        stateCoord.reset()

        // Reset recovery state for the new goal
        recovery.clearState(forGoal: taskContext.goal.id)

        for stepIndex in 0..<budget.maxSteps {

            // ── 1. Observe → state bundle ────────────────
            let bundle = stateCoord.buildBundle(
                taskContext: taskContext,
                stepIndex: stepIndex
            )

            // ── 2. Goal-reached check ────────────────────
            if decisionCoord.isGoalReached(bundle: bundle) {
                learningCoord.finalize(
                    goal: taskContext.goal,
                    succeeded: true,
                    stepCount: stepIndex
                )
                return LoopOutcome(
                    reason: .goalAchieved,
                    finalSnapshot: bundle.snapshot,
                    steps: stepIndex,
                    recoveries: budgetState.recoveries
                )
            }

            // ── 3. Plan ──────────────────────────────────
            let plan = decisionCoord.decide(from: bundle)
            guard !plan.actions.isEmpty else {
                learningCoord.finalize(
                    goal: taskContext.goal,
                    succeeded: false,
                    stepCount: stepIndex
                )
                return LoopOutcome(
                    reason: .noViablePlan,
                    finalSnapshot: bundle.snapshot,
                    steps: stepIndex,
                    recoveries: budgetState.recoveries
                )
            }

            // ── 4. Execute each action in the plan step ──
            var planSucceeded = true
            var stepTermination: LoopTerminationReason?

            for action in plan.actions {

                // 4a. Policy + skill gate
                let prepared = executionCoord.prepare(
                    intent: action,
                    snapshot: bundle.snapshot
                )

                guard prepared.policyAllowed else {
                    runtime.eventBus.emit(.policyBlocked(action))
                    stepTermination = .policyBlocked
                    planSucceeded = false
                    break
                }

                // 4b. Execute
                let startTime = Date()
                let result = executor.execute(action: prepared.intent)
                let latencyMs = Date().timeIntervalSince(startTime) * 1000

                // 4c. Critic evaluation
                let evaluation = critic.evaluate(
                    action: prepared.intent,
                    result: result,
                    preStateHash: result.preStateHash,
                    postStateHash: result.postStateHash
                )

                runtime.eventBus.emit(.actionCompleted(prepared.intent, result))
                runtime.eventBus.emit(.criticEvaluated(prepared.intent, evaluation))

                // 4d. Learn from outcome
                if result.success {
                    learningCoord.recordSuccess(
                        intent: prepared.intent,
                        bundle: bundle,
                        latencyMs: latencyMs
                    )
                    budgetState.resetExploration()
                } else {
                    learningCoord.recordFailure(
                        intent: prepared.intent,
                        bundle: bundle,
                        latencyMs: latencyMs
                    )
                }

                // 4e. Recovery on failure
                if evaluation.verdict == .failure || evaluation.verdict == .unknown {
                    guard budgetState.canRecover(under: budget) else {
                        learningCoord.finalize(
                            goal: taskContext.goal,
                            succeeded: false,
                            stepCount: stepIndex + 1
                        )
                        return LoopOutcome(
                            reason: .recoveryBudgetExhausted,
                            finalSnapshot: bundle.snapshot,
                            steps: stepIndex + 1,
                            recoveries: budgetState.recoveries
                        )
                    }

                    let recoveryDecision = recovery.recover(
                        action: prepared.intent,
                        evaluation: evaluation,
                        goalID: taskContext.goal.id
                    )
                    budgetState.registerRecovery(budget: budget)
                    learningCoord.recordRecovery()

                    switch recoveryDecision {
                    case .retry:
                        // Retry is handled by the next loop iteration
                        planSucceeded = false
                    case .skip(let reason):
                        print("[agentLoop] skip: \(reason)")
                        planSucceeded = false
                    case .abort(let reason):
                        print("[agentLoop] abort: \(reason)")
                        learningCoord.finalize(
                            goal: taskContext.goal,
                            succeeded: false,
                            stepCount: stepIndex + 1
                        )
                        return LoopOutcome(
                            reason: .unrecoverableFailure,
                            finalSnapshot: bundle.snapshot,
                            steps: stepIndex + 1,
                            recoveries: budgetState.recoveries
                        )
                    }
                }
            }

            // ── 5. Step budget check ─────────────────────
            if let forced = stepTermination {
                learningCoord.finalize(
                    goal: taskContext.goal,
                    succeeded: false,
                    stepCount: stepIndex + 1
                )
                return LoopOutcome(
                    reason: forced,
                    finalSnapshot: bundle.snapshot,
                    steps: stepIndex + 1,
                    recoveries: budgetState.recoveries
                )
            }

            _ = budgetState.incrementStep(budget: budget)
        }

        // ── Fell through: max steps ──────────────────────
        learningCoord.finalize(
            goal: taskContext.goal,
            succeeded: false,
            stepCount: budget.maxSteps
        )
        return LoopOutcome(
            reason: .maxSteps,
            finalSnapshot: runtime.worldModel.snapshot,
            steps: budget.maxSteps,
            recoveries: budgetState.recoveries
        )
    }
}
