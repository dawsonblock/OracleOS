import Foundation

// ─────────────────────────────────────────────────────────
// OracleRuntime — thin façade over subsystem references
//
// OracleRuntime holds subsystem references and provides
// lifecycle management. It does NOT contain execution logic.
// All goal processing flows through CommandDispatcher → AgentLoop.
//
// Blueprint ref: Gate 1, §1.5 — "OracleRuntime is a thin façade"
//
// Invariants:
//   • One runtime loop
//   • One planner entry point (PlanGenerator)
//   • One execution pipeline (VerifiedActionExecutor)
//   • One memory truth store (GraphStore)
//   • Every external capability behind an adapter
//   • No sidecar may mutate system state directly
//   • No execution logic in this file — delegate to AgentLoop
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

    /// The integrated agent control loop — ties all coordinators together.
    public private(set) lazy var agentLoop: AgentLoop = AgentLoop(runtime: self)

    // ── Command Dispatcher ───────────────────────────────

    /// Single intake point — normalizes all inbound work into AgentLoop.
    public private(set) lazy var commandDispatcher: CommandDispatcher = {
        let dispatcher = CommandDispatcher()
        dispatcher.attach(runtime: self)
        return dispatcher
    }()

    // ── Strategy layer ───────────────────────────────────

    /// Chooses the high-level strategy at the start of each planning cycle.
    public private(set) lazy var strategySelector: StrategySelector = StrategySelector()

    /// Tracks the active strategy and decides when to re-evaluate.
    public private(set) lazy var strategyEvaluator: StrategyEvaluator = StrategyEvaluator()

    /// In-memory catalogue of candidate and promoted workflow plans.
    public private(set) lazy var workflowIndex: WorkflowIndex = WorkflowIndex()

    /// Matches an incoming goal to promoted workflow plans in the index.
    public private(set) lazy var workflowMatcher: WorkflowMatcher = WorkflowMatcher()

    /// Built-in library of recovery strategy descriptors.
    public private(set) lazy var recoveryStrategyLibrary: RecoveryStrategyLibrary = RecoveryStrategyLibrary()

    /// Selects and prepares recovery strategies from the library.
    public private(set) lazy var recoveryStrategySelector: RecoveryStrategySelector = RecoveryStrategySelector(library: recoveryStrategyLibrary)

    /// In-memory recipe catalogue.
    public private(set) lazy var recipeStore: RecipeStore = RecipeStore()

    /// Orchestrates architecture governance, dependency analysis, and refactor planning.
    public private(set) lazy var architectureEngine: ArchitectureEngine = ArchitectureEngine()

    /// Routes memory queries across execution, pattern, and project tiers.
    public private(set) lazy var memoryRouter: MemoryRouter = MemoryRouter()

    /// LLM client for reasoning and proposal generation.
    public private(set) lazy var llmClient: LLMClient = LLMClient()

    /// Registry of all reasoning operators.
    public private(set) lazy var operatorRegistry: OperatorRegistry = .shared

    /// Proposes ranked action plans from deterministic and LLM sources.
    public private(set) lazy var proposalEngine: ProposalEngine = ProposalEngine(
        llmClient: llmClient,
        reasoningEngine: ReasoningEngine()
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

        // Core subsystem wiring
        RuntimeBootstrapper.bootstrap(self)

        // Strategy layer warm-up
        _ = strategySelector
        _ = strategyEvaluator

        // Workflow layer warm-up
        _ = workflowIndex
        _ = workflowMatcher

        // Enhanced recovery layer warm-up
        _ = recoveryStrategyLibrary
        _ = recoveryStrategySelector

        // Recipe store warm-up
        _ = recipeStore

        // Architecture engine warm-up
        _ = architectureEngine

        // Memory router warm-up
        _ = memoryRouter

        // Reasoning layer warm-up
        _ = operatorRegistry
        _ = proposalEngine

        // Diagnostics baseline
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

    // ── Goal processing — thin delegate ─────────────────
    //
    // All goal processing flows through CommandDispatcher → AgentLoop.
    // This method is kept as a convenience façade for existing callers
    // (tests, CLI, run-loop). It adds no execution logic of its own.

    public func process(goal: Goal) {
        // Single-shot: generate one plan, execute its actions, return.
        // Matches pre-refactor behaviour and keeps unit tests fast.
        // Autonomous multi-step operation goes through agentLoop.run() directly.
        let result = commandDispatcher.submitGoal(
            goal,
            from: .runtime,
            budget: LoopBudget(maxSteps: 1)
        )
        if !result.accepted {
            print("[oracle] Goal rejected: \(result.reason)")
        }
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
