import Foundation

// MARK: - SimulatedOutcome

/// The result of simulating a plan candidate.
public struct SimulatedOutcome: Sendable, Equatable {
    public let successProbability: Double
    public let estimatedSteps: Int
    public let riskScore: Double
    public let likelyFailureMode: String?
    public let reasons: [String]

    public init(
        successProbability: Double,
        estimatedSteps: Int,
        riskScore: Double,
        likelyFailureMode: String? = nil,
        reasons: [String] = []
    ) {
        self.successProbability = successProbability
        self.estimatedSteps = estimatedSteps
        self.riskScore = riskScore
        self.likelyFailureMode = likelyFailureMode
        self.reasons = reasons
    }
}

// MARK: - PlanSourceType

/// The origin/source type of a generated plan.
public enum PlanSourceType: String, Sendable, Codable, Equatable {
    case workflow
    case stableGraph = "stable_graph"
    case reasoning
    case candidateGraph = "candidate_graph"
    case exploration
    case llm
    case recovery
    case strategy

    /// Convert from planner source.
    public static func from(_ source: PlannerSource) -> PlanSourceType {
        switch source {
        case .workflow: return .workflow
        case .stableGraph: return .stableGraph
        case .candidateGraph: return .candidateGraph
        case .exploration: return .exploration
        case .recovery: return .recovery
        }
    }
}

// MARK: - PlanCandidate

/// A candidate plan consisting of one or more operators, a projected state, and scoring metadata.
public struct PlanCandidate: Sendable {
    public let operators: [Operator]
    public let projectedState: ReasoningPlanningState?
    public let score: Double
    public let reasons: [String]
    public let simulatedOutcome: SimulatedOutcome?
    public let estimatedCost: Double
    public let riskScore: Double
    public let successProbability: Double
    public let sourceType: PlanSourceType
    /// The operator families used by this plan's operators.
    public let operatorFamilies: [OperatorFamily]

    public init(
        operators: [Operator],
        projectedState: ReasoningPlanningState? = nil,
        score: Double = 0,
        reasons: [String] = [],
        simulatedOutcome: SimulatedOutcome? = nil,
        estimatedCost: Double? = nil,
        riskScore: Double? = nil,
        successProbability: Double? = nil,
        sourceType: PlanSourceType = .reasoning
    ) {
        self.operators = operators
        self.projectedState = projectedState
        self.score = score
        self.reasons = reasons
        self.simulatedOutcome = simulatedOutcome
        self.estimatedCost = estimatedCost ?? operators.reduce(0.0) { $0 + $1.baseCost }
        self.riskScore = riskScore ?? operators.reduce(0.0) { $0 + $1.risk } / Double(max(operators.count, 1))
        self.successProbability = successProbability ?? simulatedOutcome?.successProbability ?? 0
        self.sourceType = sourceType
        self.operatorFamilies = Array(Set(operators.map(\.kind.operatorFamily)))
    }

    /// Returns true if all operator families in this plan are allowed by the strategy.
    public func isAllowed(by strategy: SelectedStrategy) -> Bool {
        operatorFamilies.allSatisfy { strategy.allows($0) }
    }
}
