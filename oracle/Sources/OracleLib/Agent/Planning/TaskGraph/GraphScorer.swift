import Foundation

public struct GraphScorer: Sendable {
    public let successWeight: Double
    public let workflowWeight: Double
    public let memoryWeight: Double
    public let goalAlignmentWeight: Double
    public let costPenaltyWeight: Double
    public let riskPenaltyWeight: Double
    public let strategyFitWeight: Double

    public init(
        successWeight: Double = 0.28,
        workflowWeight: Double = 0.13,
        memoryWeight: Double = 0.13,
        goalAlignmentWeight: Double = 0.22,
        costPenaltyWeight: Double = 0.08,
        riskPenaltyWeight: Double = 0.07,
        strategyFitWeight: Double = 0.12
    ) {
        self.successWeight = successWeight
        self.workflowWeight = workflowWeight
        self.memoryWeight = memoryWeight
        self.goalAlignmentWeight = goalAlignmentWeight
        self.costPenaltyWeight = costPenaltyWeight
        self.riskPenaltyWeight = riskPenaltyWeight
        self.strategyFitWeight = strategyFitWeight
    }

    public struct ScoreBreakdown: Sendable {
        public let predictedSuccess: Double
        public let workflowSimilarity: Double
        public let memoryBias: Double
        public let goalAlignment: Double
        public let costPenalty: Double
        public let riskPenalty: Double
        public let noveltyBonus: Double
        public let strategyFit: Double
        public let total: Double

        public func toDict() -> [String: Any] {
            [
                "predicted_success": predictedSuccess,
                "workflow_similarity": workflowSimilarity,
                "memory_bias": memoryBias,
                "goal_alignment": goalAlignment,
                "cost_penalty": costPenalty,
                "risk_penalty": riskPenalty,
                "novelty_bonus": noveltyBonus,
                "strategy_fit": strategyFit,
                "total": total,
            ]
        }
    }

    public func scoreEdge(
        _ edge: TaskEdge,
        goalState: AbstractTaskState? = nil,
        targetState: AbstractTaskState? = nil,
        workflowBias: Double = 0,
        memoryBias: Double = 0,
        allowedFamilies: [OperatorFamily] = []
    ) -> Double {
        scoreEdgeWithBreakdown(
            edge,
            goalState: goalState,
            targetState: targetState,
            workflowBias: workflowBias,
            memoryBias: memoryBias,
            allowedFamilies: allowedFamilies
        ).total
    }

    public func scoreEdgeWithBreakdown(
        _ edge: TaskEdge,
        goalState: AbstractTaskState? = nil,
        targetState: AbstractTaskState? = nil,
        workflowBias: Double = 0,
        memoryBias: Double = 0,
        allowedFamilies: [OperatorFamily] = []
    ) -> ScoreBreakdown {
        let success = edge.successProbability
        let noveltyBonus: Double = edge.attempts < 3 ? 0.1 : 0
        let goalAlignment = goalAlignmentScore(targetState: targetState, goalState: goalState)
        let costPenalty = normalizedCost(edge.averageCost)
        let riskPenalty = edge.risk
        let strategyFit: Double = allowedFamilies.isEmpty ? 0 : (allowedFamilies.contains(edge.operatorFamily) ? 1.0 : 0.0)

        let total = (successWeight * success)
            + (workflowWeight * min(1, max(0, workflowBias)))
            + (memoryWeight * min(1, max(0, memoryBias)))
            + (goalAlignmentWeight * goalAlignment)
            + (strategyFitWeight * strategyFit)
            - (costPenaltyWeight * costPenalty)
            - (riskPenaltyWeight * riskPenalty)
            + noveltyBonus

        return ScoreBreakdown(
            predictedSuccess: successWeight * success,
            workflowSimilarity: workflowWeight * min(1, max(0, workflowBias)),
            memoryBias: memoryWeight * min(1, max(0, memoryBias)),
            goalAlignment: goalAlignmentWeight * goalAlignment,
            costPenalty: -(costPenaltyWeight * costPenalty),
            riskPenalty: -(riskPenaltyWeight * riskPenalty),
            noveltyBonus: noveltyBonus,
            strategyFit: strategyFitWeight * strategyFit,
            total: total
        )
    }

    public func scorePath(_ edges: [TaskEdge], goal: Goal? = nil) -> Double {
        guard !edges.isEmpty else { return 0 }
        return edges.reduce(0.0) { $0 + scoreEdge($1, goalState: goal.flatMap(Self.goalAbstractState)) }
    }

    private func goalAlignmentScore(
        targetState: AbstractTaskState?,
        goalState: AbstractTaskState?
    ) -> Double {
        guard let target = targetState, let goal = goalState else { return 0 }
        if target == goal { return 1.0 }
        if Self.relatedStates(target, goal) { return 0.4 }
        return 0
    }

    private static func relatedStates(_ a: AbstractTaskState, _ b: AbstractTaskState) -> Bool {
        let groups: [[AbstractTaskState]] = [
            [.buildRunning, .buildSucceeded, .buildFailed],
            [.testsRunning, .testsPassed, .failingTestIdentified],
            [.candidatePatchGenerated, .candidatePatchApplied, .patchVerified, .patchRejected],
            [.loginPageDetected, .formVisible, .navigationCompleted],
            [.repoLoaded, .repoIndexed],
        ]
        return groups.contains { $0.contains(a) && $0.contains(b) }
    }

    public static func goalAbstractState(from goal: Goal) -> AbstractTaskState? {
        let desc = goal.description.lowercased()
        if desc.contains("test") && desc.contains("pass") { return .testsPassed }
        if desc.contains("test") && desc.contains("fix") { return .testsPassed }
        if desc.contains("test") && desc.contains("run") { return .testsRunning }
        if desc.contains("build") && desc.contains("fix") { return .buildSucceeded }
        if desc.contains("build") { return .buildSucceeded }
        if desc.contains("patch") { return .patchVerified }
        if desc.contains("login") { return .loginPageDetected }
        if desc.contains("navigate") { return .navigationCompleted }
        if desc.contains("complete") || desc.contains("done") { return .goalReached }
        return nil
    }

    private func normalizedCost(_ cost: Double) -> Double {
        min(max(cost / 10.0, 0), 1)
    }
}