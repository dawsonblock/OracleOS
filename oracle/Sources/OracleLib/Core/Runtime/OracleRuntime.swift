import Foundation

// ─────────────────────────────────────────────────────────
// OracleRuntime — single execution spine
//
// Invariants:
//   • One runtime loop
//   • One planner entry point (PlanGenerator)
//   • One execution pipeline (VerifiedActionExecutor)
//   • One memory truth store (GraphStore)
//   • Every external capability behind an adapter
//   • No sidecar may mutate system state directly
// ─────────────────────────────────────────────────────────

public final class OracleRuntime {

    public let version = "0.1.0"

    // ── Subsystems ──────────────────────────────────────

    public let planner = PlanGenerator()
    public let executor = VerifiedActionExecutor()
    public let policy = PolicyEngine()
    public let memory = GraphStore()
    public let traceRecorder = TraceRecorder()
    public let eventBus = EventBus()
    public lazy var diagnostics = SystemDashboard(traceRecorder: traceRecorder, eventBus: eventBus)

    // ── Sidecar adapters (optional) ─────────────────────

    public let sandboxExecutor = SandboxExecutor()
    public let codeQuery = CodeQueryEngine()
    public let webExtractor = WebExtractor()
    public let contextRetriever = ContextRetriever()
    public lazy var searchController = SearchController(codeQuery: codeQuery, graphStore: memory, webExtractor: webExtractor)

    // ── Critic + Recovery ───────────────────────────────

    public let critic = CriticLoop()
    public let recovery = RecoveryCoordinator()

    // ── Replay + State Memory + Metrics ─────────────────

    public let replayEngine = TraceReplayEngine()
    public let stateMemory = StateMemoryIndex()
    public let metrics = MetricsRecorder()

    // ── Lazy-init subsystems (depend on other subsystems) ──

    private(set) lazy var contextAssembler: ContextAssembler = ContextAssembler(
        graphStore: memory,
        codeQuery: codeQuery,
        retriever: contextRetriever
    )

    // ── State ───────────────────────────────────────────

    private var isRunning = false

    public init() {}

    // ── Lifecycle ───────────────────────────────────────

    public func initialize() {

        print("[oracle] Runtime initializing")

        // 1. Graph truth store
        memory.initialize()

        // 2. Wire policy into executor
        executor.attachPolicy(policy)
        executor.attachTraceRecorder(traceRecorder)

        // 3. Register built-in actions
        ActionRegistry.shared.registerDefaults()

        // 4. Diagnostics baseline
        diagnostics.attachMetrics(metrics)
        diagnostics.attachCritic(critic)
        diagnostics.printStatus()

        print("[oracle] Runtime ready")
    }

    public func run() {

        isRunning = true
        print("[oracle] Agent loop started")

        while isRunning {

            if let goal = GoalInterpreter.nextGoal() {
                process(goal: goal)
            }

            Thread.sleep(forTimeInterval: 0.5)
        }

        print("[oracle] Agent loop stopped")
    }

    public func stop() {
        isRunning = false
    }

    // ── Core pipeline ───────────────────────────────────
    //
    // goal
    //   → context retrieval
    //   → plan generation
    //   → for each action:
    //       → policy validation
    //       → action execution
    //       → critic evaluation
    //       → on failure: recovery (retry / skip / abort)
    //       → trace recording
    //       → memory update

    public func process(goal: Goal) {

        let assembled = contextAssembler.assemble(goal: goal, plan: nil)

        // Inject recent verified traces from the memory graph as planning precedent
        let recentTraces = memory.recentTraces(limit: 5)
        let plan = planner.generate(goal: goal, context: assembled.text, recentTraces: recentTraces)

        eventBus.emit(.planGenerated(plan))

        // ── Begin replay trace for this goal ─────────────
        let traceID = replayEngine.beginTrace(goalID: goal.id, goalDescription: goal.description)

        // ── Build state signature for state memory ───────
        let stateSignature = StateSignature.from(
            context: assembled.text,
            actionTypes: plan.actions.map { $0.type }
        )

        var aborted = false
        var stepCount = 0
        var allSucceeded = true

        for action in plan.actions {

            // ── Policy gate ──────────────────────────────
            guard policy.allow(action: action) else {
                print("[oracle] BLOCKED by policy: \(action.type)")
                traceRecorder.record(
                    TraceEvent(action: action, outcome: .blocked, detail: "policy denied")
                )
                eventBus.emit(.policyBlocked(action))
                continue
            }

            // ── Execute (with recovery loop) ─────────────
            let startTime = Date()
            let (finalResult, finalEvaluation) = executeWithRecovery(
                action: action,
                goalID: goal.id
            )
            let latencyMs = Date().timeIntervalSince(startTime) * 1000

            stepCount += 1

            // ── Record replay step ───────────────────────
            replayEngine.recordStep(
                actionType: action.type,
                actionID: action.id,
                preStateHash: finalResult.preStateHash,
                postStateHash: finalResult.postStateHash,
                verdict: finalEvaluation.verdict,
                latencyMs: latencyMs
            )

            // ── Record metrics ───────────────────────────
            metrics.recordAction(type: action.type, success: finalResult.success)
            metrics.recordLatency(latencyMs)

            // ── Update state memory ──────────────────────
            stateMemory.record(
                stateSignature: stateSignature,
                actionType: action.type,
                success: finalResult.success
            )

            // ── Memory commit ────────────────────────────
            memory.record(result: finalResult, forAction: action)

            // ── Trace ────────────────────────────────────
            let outcome: TraceOutcome = finalResult.success ? .success : .failure
            traceRecorder.record(
                TraceEvent(action: action, outcome: outcome, detail: finalResult.detail)
            )

            eventBus.emit(.actionCompleted(action, finalResult))
            eventBus.emit(.criticEvaluated(action, finalEvaluation))

            if !finalResult.success { allSucceeded = false }

            // ── Track recovery attempts in metrics ───────
            if let state = recovery.state(forGoal: goal.id) {
                let recoveryCount = state.retryCountPerAction[action.id, default: 0]
                for _ in 0..<recoveryCount {
                    metrics.recordRecovery()
                }
            }

            // ── Abort if recovery coordinator says so ────
            if case .abort(let reason) = shouldAbort(evaluation: finalEvaluation, action: action, goalID: goal.id) {
                print("[oracle] ABORT: \(reason)")
                eventBus.emit(.goalAborted(goal, reason))
                aborted = true
                allSucceeded = false
                break
            }

            // ── Halt plan on unrecovered failure ─────────
            if !finalResult.success && finalEvaluation.verdict == .failure {
                print("[oracle] Action failed after recovery, halting plan: \(action.type)")
                allSucceeded = false
                break
            }
        }

        // ── Complete replay trace ────────────────────────
        _ = replayEngine.endTrace()

        // ── Record goal metrics ─────────────────────────
        metrics.recordGoal(success: allSucceeded, stepCount: stepCount)

        // Clean up recovery state for this goal
        recovery.clearState(forGoal: goal.id)

        if !aborted {
            eventBus.emit(.goalCompleted(goal))
        }
    }

    // ── Execution + Recovery loop ───────────────────────
    //
    // Executes an action, evaluates via critic, and if the
    // critic signals failure, asks the RecoveryCoordinator
    // for a decision. Retries are bounded.

    private func executeWithRecovery(
        action: ActionIntent,
        goalID: String
    ) -> (ExecutionResult, CriticEvaluation) {

        var currentAction = action
        var attempts = 0
        let maxAttempts = RecoveryCoordinator.maxRetriesPerAction + 1

        while attempts < maxAttempts {
            attempts += 1

            // Execute
            let result: ExecutionResult
            if policy.requiresSandbox(action: currentAction) {
                result = sandboxExecutor.run(action: currentAction)
            } else {
                result = executor.execute(action: currentAction)
            }

            // Critic evaluation
            let evaluation = critic.evaluate(
                action: currentAction,
                result: result,
                preStateHash: result.preStateHash,
                postStateHash: result.postStateHash
            )

            // Success or partial success — accept and move on
            if evaluation.verdict == .success {
                return (result, evaluation)
            }

            if evaluation.verdict == .partialSuccess {
                // Accept partial success — side effects already happened
                return (result, evaluation)
            }

            // Failure or unknown — ask recovery coordinator
            let decision = recovery.recover(
                action: currentAction,
                evaluation: evaluation,
                goalID: goalID
            )

            eventBus.emit(.recoveryAttempted(currentAction, decision))

            switch decision {
            case .retry(let retryAction):
                currentAction = retryAction
                continue

            case .skip(let reason):
                print("[oracle] Skipping \(currentAction.type): \(reason)")
                return (result, evaluation)

            case .abort(let reason):
                print("[oracle] Recovery abort: \(reason)")
                return (result, evaluation)
            }
        }

        // Should not reach here, but defensive return
        let fallbackResult = ExecutionResult(
            success: false,
            detail: "max recovery attempts exceeded",
            executedThroughExecutor: true,
            actionID: currentAction.id
        )
        let fallbackEval = critic.evaluate(
            action: currentAction,
            result: fallbackResult,
            preStateHash: "",
            postStateHash: ""
        )
        return (fallbackResult, fallbackEval)
    }

    /// Check if the recovery coordinator recommends aborting the entire goal
    private func shouldAbort(
        evaluation: CriticEvaluation,
        action: ActionIntent,
        goalID: String
    ) -> RecoveryDecision? {
        // Only check for abort if critic recommends recovery
        guard critic.shouldRecommendRecovery() else { return nil }

        // Check if goal-level budget is exhausted
        if let state = recovery.state(forGoal: goalID),
           state.totalRecoveryAttempts >= RecoveryCoordinator.maxRecoveryPerGoal {
            return .abort(reason: "goal recovery budget exhausted")
        }
        return nil
    }
}
