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

    // ── Task Graph (live planning substrate) ────────────

    public let taskGraph = TaskGraphStore()

    // ── Planning Graph (finite action graph) ────────────

    public let planningGraphEngine = PlanningGraphEngine()

    // ── World State pipeline ────────────────────────────

    public let worldModel = WorldStateModel()
    public let schemaLibrary = ActionSchemaLibrary()

    // previousObservation tracks the last observation for delta detection
    private var previousObservation: Observation?

    // ── Candidate generation (search-centric selection) ──

    public private(set) lazy var candidateGenerator: CandidateGenerator = CandidateGenerator(
        stateMemoryIndex: stateMemory,
        planningGraphEngine: planningGraphEngine
    )

    // ── Skills registry ──────────────────────────────────

    public private(set) lazy var skillRegistry: SkillRegistry = SkillRegistry.live()

    // ── Coordinator layer ────────────────────────────────

    /// Observation → WorldModelSnapshot pipeline (owns state mutation).
    public private(set) lazy var stateCoordinator: StateCoordinator = StateCoordinator(
        worldModel: worldModel
    )

    /// Sole planner façade — plans but never executes.
    public private(set) lazy var decisionCoordinator: DecisionCoordinator = DecisionCoordinator(
        planner: planner,
        graphStore: memory,
        stateMemory: stateMemory
    )

    /// Skill resolution + policy gate — prepares but never executes.
    public private(set) lazy var executionCoordinator: ExecutionCoordinator = ExecutionCoordinator(
        skillRegistry: skillRegistry,
        policy: policy
    )

    /// Outcome persistence — records into metrics and state memory.
    public private(set) lazy var learningCoordinator: LearningCoordinator = LearningCoordinator(
        metrics: metrics,
        stateMemory: stateMemory
    )

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

        // 4. Task graph initial position
        taskGraph.updateCurrentNode(context: "idle")

        // 5. Wire candidate generator into search controller
        searchController.attachCandidateGenerator(candidateGenerator)

        // 6. Load skill registry (triggers lazy init, registering all built-in skills)
        _ = skillRegistry

        // 7. Warm up coordinator layer (triggers lazy init for all four coordinators)
        _ = stateCoordinator
        _ = decisionCoordinator
        _ = executionCoordinator
        _ = learningCoordinator

        // 8. Diagnostics baseline
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

            // ── Update task graph ──────────────────────
            let candidateEdge = taskGraph.addCandidateEdge(
                action: action.type,
                domain: action.domain,
                targetState: taskGraph.abstractState(from: finalResult.detail)
            )
            if let edge = candidateEdge {
                if finalResult.success {
                    taskGraph.recordVerifiedExecution(
                        edgeID: edge.id,
                        resultContext: finalResult.detail,
                        latencyMs: latencyMs,
                        cost: 1.0,
                        createdByAction: action.type
                    )
                } else {
                    taskGraph.recordFailedExecution(
                        edgeID: edge.id,
                        latencyMs: latencyMs,
                        cost: 1.0
                    )
                }
            }

            // ── Update planning graph with critic verdict ─
            if let edge = planningGraphEngine.findEdge(
                from: stateSignature.hash,
                to: finalResult.postStateHash,
                actionType: action.type
            ) {
                planningGraphEngine.recordTraversal(
                    edgeID: edge.id,
                    success: finalResult.success,
                    cost: 1.0,
                    latencyMs: latencyMs
                )
            } else {
                let newEdge = planningGraphEngine.addEdge(
                    from: stateSignature.hash,
                    to: finalResult.postStateHash,
                    actionType: action.type,
                    domain: action.domain
                )
                planningGraphEngine.recordTraversal(
                    edgeID: newEdge.id,
                    success: finalResult.success,
                    cost: 1.0,
                    latencyMs: latencyMs
                )
            }

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

    // ── Observation intake ──────────────────────────────
    //
    // Called each loop iteration to feed a fresh observation
    // through the perception pipeline:
    //   observation → delta → diff → world model update
    //
    // The compressed UI state is returned for optional use
    // in plan generation or prompt construction.

    @discardableResult
    public func ingestObservation(_ observation: Observation) -> CompressedUIState {

        // 1. Delta detection
        let delta: ObservationDelta
        if let prev = previousObservation {
            delta = ObservationChangeDetector.detect(previous: prev, incoming: observation)
        } else {
            // First observation — treat everything as new
            delta = ObservationDelta(
                applicationChanged: observation.app.map {
                    .init(from: nil, to: $0)
                },
                addedElements: observation.elements
            )
        }

        // 2. Produce StateDiff (uses delta when available)
        let diff: StateDiff
        if previousObservation != nil {
            diff = StateDiffEngine.diff(
                current: worldModel.snapshot,
                incoming: observation,
                delta: delta
            )
        } else {
            diff = StateDiffEngine.diff(
                current: worldModel.snapshot,
                incoming: observation
            )
        }

        // 3. Apply to world model
        if !diff.isEmpty {
            worldModel.apply(diff: diff)
        }

        // 4. Compress for planning
        let compressed = StateAbstractionEngine.compress(observation: observation)

        // 5. Stash for next delta
        previousObservation = observation

        return compressed
    }

    /// Current world snapshot for external consumers.
    public var currentWorldSnapshot: WorldModelSnapshot {
        worldModel.snapshot
    }
}
