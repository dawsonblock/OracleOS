import Foundation

// MARK: - ActionContract

/// Canonical description of an action that can be dispatched by the planner.
public struct ActionContract: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let agentKind: AgentKind
    public let domain: String
    public let skillName: String
    public let targetRole: String?
    public let targetLabel: String?
    public let locatorStrategy: String
    public let workspaceRelativePath: String?
    public let commandCategory: String?
    public let plannerFamily: String?

    public init(
        id: String,
        agentKind: AgentKind = .mixed,
        domain: String? = nil,
        skillName: String,
        targetRole: String?,
        targetLabel: String?,
        locatorStrategy: String,
        workspaceRelativePath: String? = nil,
        commandCategory: String? = nil,
        plannerFamily: String? = nil
    ) {
        self.id = id
        self.agentKind = agentKind
        self.domain = domain ?? (agentKind == .code ? "code" : "os")
        self.skillName = skillName
        self.targetRole = targetRole
        self.targetLabel = targetLabel
        self.locatorStrategy = locatorStrategy
        self.workspaceRelativePath = workspaceRelativePath
        self.commandCategory = commandCategory
        self.plannerFamily = plannerFamily
    }
}

// MARK: - PlannerFamily

/// High-level grouping of planners by domain.
public enum PlannerFamily: String, Codable, Sendable, CaseIterable {
    case os
    case code
    case mixed

    public static func from(agentKind: AgentKind) -> PlannerFamily {
        switch agentKind {
        case .code: return .code
        case .ui: return .os
        case .mixed: return .mixed
        }
    }
}

// MARK: - TaskStepPhase

/// The execution phase a task step belongs to.
public enum TaskStepPhase: String, Codable, Sendable, CaseIterable {
    case operatingSystem
    case engineering
    case handoff
}

// MARK: - ElementQuery

/// A query for a specific UI element.
public struct ElementQuery: Sendable {
    public let text: String?
    public let role: String?
    public let editable: Bool?
    public let clickable: Bool?
    public let visibleOnly: Bool
    public let app: String?

    public init(
        text: String? = nil,
        role: String? = nil,
        editable: Bool? = nil,
        clickable: Bool? = nil,
        visibleOnly: Bool = true,
        app: String? = nil
    ) {
        self.text = text
        self.role = role
        self.editable = editable
        self.clickable = clickable
        self.visibleOnly = visibleOnly
        self.app = app
    }
}

// MARK: - CodeCommandCategory

/// Category for code/engineering commands.
public enum CodeCommandCategory: String, Codable, Sendable, CaseIterable {
    case test
    case build
    case editFile = "edit_file"
    case generatePatch = "generate_patch"
    case gitStatus = "git_status"
    case search
    case lint
    case format
}

// MARK: - WorldState

/// Simplified world state used by the Reasoning layer.
public struct WorldState: Sendable {
    public var observation: Observation
    public var planningState: PlanningState
    public var repositorySnapshot: RepositorySnapshot?
    public var lastAction: ActionIntent?

    public init(
        observation: Observation = Observation(),
        planningState: PlanningState = PlanningState(
            id: PlanningStateID(rawValue: "default"),
            clusterKey: StateClusterKey(rawValue: "default"),
            appID: ""
        ),
        repositorySnapshot: RepositorySnapshot? = nil,
        lastAction: ActionIntent? = nil
    ) {
        self.observation = observation
        self.planningState = planningState
        self.repositorySnapshot = repositorySnapshot
        self.lastAction = lastAction
    }
}

// MARK: - WorkflowMatch

/// A matching workflow plan with a relevance score.
public struct WorkflowMatch: Sendable {
    public let plan: WorkflowPlan
    public let score: Double
    public let stepIndex: Int

    public init(plan: WorkflowPlan, score: Double, stepIndex: Int = 0) {
        self.plan = plan
        self.score = score
        self.stepIndex = stepIndex
    }
}

// MARK: - WorkflowStep+ActionContract

extension WorkflowStep {
    /// A synthesised `ActionContract` derived from the step's skill name.
    public var actionContract: ActionContract {
        ActionContract(
            id: "workflow|\(id)|\(skillName)",
            agentKind: agentKind,
            skillName: skillName,
            targetRole: nil,
            targetLabel: nil,
            locatorStrategy: "workflow"
        )
    }
}

// MARK: - WorkflowRetriever

/// Retrieves the best matching workflow for a given goal / world state.
public struct WorkflowRetriever: Sendable {
    public init() {}

    public func retrieve(
        goal: Goal,
        taskContext: TaskContext,
        worldState: WorldState,
        workflowIndex: WorkflowIndex,
        memoryStore: AppMemoryStore,
        selectedStrategy: SelectedStrategy?
    ) -> WorkflowMatch? {
        let matches = workflowIndex.matching(goal: goal)
        guard let best = matches.first else { return nil }
        return WorkflowMatch(plan: best, score: 0.8, stepIndex: 0)
    }
}

// MARK: - GraphEdge

/// A directed edge in the planning graph with an action contract reference.
public struct GraphEdge: Sendable {
    public let id: String
    public let fromStateID: PlanningStateID
    public let toStateID: PlanningStateID
    public let actionContractID: String
    public let stable: Bool
    public let weight: Double

    public init(
        id: String = UUID().uuidString,
        fromStateID: PlanningStateID,
        toStateID: PlanningStateID,
        actionContractID: String,
        stable: Bool = false,
        weight: Double = 1.0
    ) {
        self.id = id
        self.fromStateID = fromStateID
        self.toStateID = toStateID
        self.actionContractID = actionContractID
        self.stable = stable
        self.weight = weight
    }
}

// MARK: - PathScorer

/// Scores a graph edge for planning purposes.
public struct PathScorer: Sendable {
    public init() {}

    public func score(
        edge: GraphEdge,
        actionContract: ActionContract,
        goal: Goal,
        memoryBias: Double,
        riskPenalty: Double
    ) -> Double {
        max(0, min(1, edge.weight + memoryBias - riskPenalty))
    }
}

// MARK: - GraphPlanner

/// Stub graph planner. Full implementation in the Graph layer.
public struct GraphPlanner: Sendable {
    public init() {}

    public func nextStep(
        taskContext: TaskContext,
        worldState: WorldState,
        graphStore: GraphStore,
        memoryStore: AppMemoryStore,
        selectedStrategy: SelectedStrategy
    ) -> PlannerDecision? { nil }
}

// MARK: - PlannerSource / PlannerExecutionMode

public enum PlannerSource: String, Codable, Sendable {
    case workflow
    case stableGraph = "stable_graph"
    case candidateGraph = "candidate_graph"
    case exploration
    case recovery
}

public enum PlannerExecutionMode: String, Codable, Sendable {
    case direct
    case experiment
}

// MARK: - PlannerDecision

/// The concrete decision produced by a family-specific planner.
public struct PlannerDecision: Sendable {
    public let agentKind: AgentKind
    public let actionContract: ActionContract
    public let source: PlannerSource
    public let plannerFamily: PlannerFamily
    public let notes: [String]
    public let planDiagnostics: PlanDiagnostics?

    public init(
        agentKind: AgentKind = .mixed,
        actionContract: ActionContract,
        source: PlannerSource,
        plannerFamily: PlannerFamily = .mixed,
        notes: [String] = [],
        planDiagnostics: PlanDiagnostics? = nil
    ) {
        self.agentKind = agentKind
        self.actionContract = actionContract
        self.source = source
        self.plannerFamily = plannerFamily
        self.notes = notes
        self.planDiagnostics = planDiagnostics
    }
}

// MARK: - OSPlanner / CodePlanner / MixedTaskPlanner

/// Stub OS planner. Full implementation in the Agent Planning layer.
public struct OSPlanner: Sendable {
    public let graphPlanner: GraphPlanner
    public let workflowIndex: WorkflowIndex
    public let workflowRetriever: WorkflowRetriever
    public let workflowExecutor: WorkflowExecutor

    public init(
        graphPlanner: GraphPlanner = GraphPlanner(),
        workflowIndex: WorkflowIndex = WorkflowIndex(),
        workflowRetriever: WorkflowRetriever = WorkflowRetriever(),
        workflowExecutor: WorkflowExecutor = WorkflowExecutor()
    ) {
        self.graphPlanner = graphPlanner
        self.workflowIndex = workflowIndex
        self.workflowRetriever = workflowRetriever
        self.workflowExecutor = workflowExecutor
    }

    public func nextStep(
        taskContext: TaskContext,
        worldState: WorldState,
        graphStore: GraphStore,
        memoryStore: AppMemoryStore,
        selectedStrategy: SelectedStrategy
    ) -> PlannerDecision? { nil }
}

/// Stub code planner. Full implementation in the Agent Planning layer.
public struct CodePlanner: Sendable {
    public let graphPlanner: GraphPlanner
    public let workflowIndex: WorkflowIndex
    public let workflowRetriever: WorkflowRetriever
    public let workflowExecutor: WorkflowExecutor

    public init(
        graphPlanner: GraphPlanner = GraphPlanner(),
        workflowIndex: WorkflowIndex = WorkflowIndex(),
        workflowRetriever: WorkflowRetriever = WorkflowRetriever(),
        workflowExecutor: WorkflowExecutor = WorkflowExecutor()
    ) {
        self.graphPlanner = graphPlanner
        self.workflowIndex = workflowIndex
        self.workflowRetriever = workflowRetriever
        self.workflowExecutor = workflowExecutor
    }

    public func nextStep(
        taskContext: TaskContext,
        worldState: WorldState,
        graphStore: GraphStore,
        memoryStore: AppMemoryStore,
        selectedStrategy: SelectedStrategy
    ) -> PlannerDecision? { nil }
}

/// Stub mixed-task planner. Full implementation in the Agent Planning layer.
public struct MixedTaskPlanner: Sendable {
    public let osPlanner: OSPlanner
    public let codePlanner: CodePlanner

    public init(osPlanner: OSPlanner = OSPlanner(), codePlanner: CodePlanner = CodePlanner()) {
        self.osPlanner = osPlanner
        self.codePlanner = codePlanner
    }

    public func nextStep(
        taskContext: TaskContext,
        worldState: WorldState,
        graphStore: GraphStore,
        memoryStore: AppMemoryStore,
        selectedStrategy: SelectedStrategy
    ) -> PlannerDecision? { nil }
}

// MARK: - WorkflowExecutor (stub for planners)

public struct WorkflowExecutor: Sendable {
    public init() {}
}
