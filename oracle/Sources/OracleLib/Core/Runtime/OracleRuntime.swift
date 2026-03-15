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
    //   → policy validation
    //   → action execution
    //   → verification
    //   → trace recording
    //   → memory update

    public func process(goal: Goal) {

        let assembled = contextAssembler.assemble(goal: goal, plan: nil)

        let plan = planner.generate(goal: goal, context: assembled.text)

        eventBus.emit(.planGenerated(plan))

        for action in plan.actions {

            // Policy gate
            guard policy.allow(action: action) else {
                print("[oracle] BLOCKED by policy: \(action.type)")
                traceRecorder.record(
                    TraceEvent(action: action, outcome: .blocked, detail: "policy denied")
                )
                continue
            }

            // Risk routing: sandbox vs local
            let result: ExecutionResult
            if policy.requiresSandbox(action: action) {
                result = sandboxExecutor.run(action: action)
            } else {
                result = executor.execute(action: action)
            }

            // Memory commit
            memory.record(result: result, forAction: action)

            // Trace
            let outcome: TraceOutcome = result.success ? .success : .failure
            traceRecorder.record(
                TraceEvent(action: action, outcome: outcome, detail: result.detail)
            )

            eventBus.emit(.actionCompleted(action, result))

            // Halt plan on failure (bounded execution)
            if !result.success {
                print("[oracle] Action failed, halting plan: \(action.type)")
                break
            }
        }

        eventBus.emit(.goalCompleted(goal))
    }
}
