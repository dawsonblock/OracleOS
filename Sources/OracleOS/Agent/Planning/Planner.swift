import Foundation

// Planner chooses execution structure only: workflow, graph path, graph edge,
// or bounded exploration. It must not resolve exact UI targets, mutate files,
// execute commands, or inline recovery mechanics.
//
// The planner navigates the live TaskGraph as its primary control substrate.
// Each planning cycle:
//   1. Updates the current task-graph node from world state
//   2. Expands candidate edges from the current node
//   3. Evaluates future paths via GraphNavigator
//   4. Selects the best edge
// The task graph is the canonical representation of task position — not
// a post-hoc log.
public class Planner {
    public let workflowIndex: WorkflowIndex
    public let workflowRetriever: WorkflowRetriever
    public let osPlanner: OSPlanner
    public let codePlanner: CodePlanner
    public let mixedTaskPlanner: MixedTaskPlanner
    public let reasoningEngine: ReasoningEngine
    public let planEvaluator: PlanEvaluator
    public let promptEngine: PromptEngine
    public let reasoningThreshold: Double
    public let graphNavigator: GraphNavigator
    public let graphScorer: GraphScorer
    public var currentGoal: Goal?
    
    private let planGenerator: PlanGenerator
    public let taskGraphStore: TaskGraphStore

    public init(
        workflowIndex: WorkflowIndex? = nil,
        osPlanner: OSPlanner? = nil,
        codePlanner: CodePlanner? = nil,
        mixedTaskPlanner: MixedTaskPlanner? = nil,
        reasoningEngine: ReasoningEngine? = nil,
        planEvaluator: PlanEvaluator? = nil,
        promptEngine: PromptEngine = PromptEngine(),
        reasoningThreshold: Double = 0.6,
        taskGraphStore: TaskGraphStore? = nil
    ) {
        self.workflowIndex = workflowIndex ?? WorkflowIndex()
        let sharedWorkflowRetriever = WorkflowRetriever()
        let sharedPlanEvaluator = planEvaluator ?? PlanEvaluator(workflowRetriever: sharedWorkflowRetriever)
        
        self.planGenerator = PlanGenerator(
            reasoningEngine: reasoningEngine ?? ReasoningEngine(),
            planEvaluator: sharedPlanEvaluator,
            osPlanner: osPlanner,
            codePlanner: codePlanner,
            mixedTaskPlanner: mixedTaskPlanner
        )
        self.workflowRetriever = sharedWorkflowRetriever
        self.osPlanner = osPlanner ?? OSPlanner()
        self.codePlanner = codePlanner ?? CodePlanner()
        self.mixedTaskPlanner = mixedTaskPlanner ?? MixedTaskPlanner(osPlanner: self.osPlanner, codePlanner: self.codePlanner)
        self.reasoningEngine = reasoningEngine ?? ReasoningEngine()
        self.planEvaluator = sharedPlanEvaluator
        self.promptEngine = promptEngine
        self.reasoningThreshold = reasoningThreshold
        self.taskGraphStore = taskGraphStore ?? TaskGraphStore()
        self.graphNavigator = GraphNavigator()
        self.graphScorer = GraphScorer()
    }


    public func setGoal(_ goal: Goal) {
        currentGoal = goal
    }

    public func interpretGoal(_ description: String) -> Goal {
        Goal.interpret(description)
    }


    public func goalReached(state: PlanningState) -> Bool {
        guard let currentGoal else { return false }
        return currentGoal.matchScore(state: state) >= 1
    }


    public func nextStep(
        worldState: WorldState,
        graphStore: GraphStore,
        memoryStore: AppMemoryStore = AppMemoryStore(),
        selectedStrategy: SelectedStrategy
    ) -> PlannerDecision? {
        guard let currentGoal else { return nil }

        let workspaceRoot = currentGoal.workspaceRoot.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let taskContext = TaskContext.from(goal: currentGoal, workspaceRoot: workspaceRoot)
        
        let memoryInfluence = MemoryRouter(memoryStore: memoryStore).influence(
            for: MemoryQueryContext(taskContext: taskContext, worldState: worldState)
        )
        let reasoningState = ReasoningPlanningState(
            taskContext: taskContext,
            worldState: worldState,
            memoryInfluence: memoryInfluence
        )

        let bestCandidate = planGenerator.bestPlan(
            state: reasoningState,
            taskContext: taskContext,
            goal: currentGoal,
            worldState: worldState,
            graphStore: graphStore,
            workflowIndex: workflowIndex,
            memoryStore: memoryStore,
            minimumScore: reasoningThreshold,
            selectedStrategy: selectedStrategy
        )

        guard let selectedPlan = bestCandidate,
              let selectedOperator = selectedPlan.operators.first,
              let actionContract = selectedOperator.actionContract(for: reasoningState, goal: currentGoal)
        else {
            return nil
        }

        return PlannerDecision(
            agentKind: selectedOperator.agentKind,
            plannerFamily: plannerFamily(for: taskContext.agentKind),
            stepPhase: selectedOperator.stepPhase,
            actionContract: actionContract,
            source: mapSource(selectedPlan.sourceType),
            fallbackReason: selectedPlan.reasons.first ?? "Reasoning-selected plan",
            semanticQuery: selectedOperator.semanticQuery(for: reasoningState, goal: currentGoal),
            projectMemoryRefs: memoryInfluence.projectMemoryRefs,
            notes: selectedPlan.reasons
        )
    }

    private func mapSource(_ source: PlanSourceType?) -> PlannerSource {
        guard let source = source else { return .exploration }
        switch source {
        case .workflow: return .workflow
        case .stableGraph: return .stableGraph
        case .candidateGraph: return .candidateGraph
        case .recovery: return .recovery
        case .exploration, .reasoning, .llm, .strategy: return .exploration
        }
    }

    private func selectBestDecision(
        familyDecision: PlannerDecision?,
        reasoningDecision: PlannerDecision?,
        taskGraphDecision: PlannerDecision? = nil,
        taskContext: TaskContext,
        worldState: WorldState,
        memoryStore: AppMemoryStore
    ) -> PlannerDecision? {
        let memoryInfluence = MemoryRouter(memoryStore: memoryStore).influence(
            for: MemoryQueryContext(taskContext: taskContext, worldState: worldState)
        )
        let memoryBias = MemoryScorer.planBias(influence: memoryInfluence)

        let taskGraphScore = taskGraphDecision.map { decision -> Double in
            let baseScore = sourceConfidence(decision.source) + memoryBias
            return baseScore + 0.1
        }
        
        let familyScore = familyDecision.map { sourceConfidence($0.source) + memoryBias }
        let reasoningScore = reasoningDecision.map { sourceConfidence($0.source) + memoryBias }

        var bestDecision: PlannerDecision? = nil
        var bestScore: Double = -1.0

        if let tg = taskGraphDecision, let score = taskGraphScore, score > bestScore {
            bestDecision = tg
            bestScore = score
        }
        if let f = familyDecision, let score = familyScore, score > bestScore {
            bestDecision = f
            bestScore = score
        }
        if let r = reasoningDecision, let score = reasoningScore, score > bestScore {
            bestDecision = r
            bestScore = score
        }
        return bestDecision
    }

    private func sourceConfidence(_ source: PlannerSource) -> Double {
        switch source {
        case .workflow: return 0.95
        case .stableGraph: return 0.90
        case .candidateGraph: return 0.85
        case .exploration: return 0.50
        case .recovery: return 0.20
        }
    }

    private func plannerFamily(for agentKind: AgentKind) -> PlannerFamily {
        switch agentKind {
        case .os:
            return .os
        case .code:
            return .code
        case .mixed:
            return .mixed
        }
    }

    public static func goalMatchScore(state: PlanningState, goal: Goal) -> Double {
        return goal.matchScore(state: state)
    }

    public func nextAction(
        worldState: WorldState,
        graphStore: GraphStore,
        selectedStrategy: SelectedStrategy
    ) -> ActionContract? {
        nextStep(worldState: worldState, graphStore: graphStore, selectedStrategy: selectedStrategy)?.actionContract
    }

    public func plan(goal: String) -> Plan {
        let interpretedGoal = interpretGoal(goal)
        setGoal(interpretedGoal)
        return Plan(goal: goal, steps: ["graph-aware"])
    }
}

