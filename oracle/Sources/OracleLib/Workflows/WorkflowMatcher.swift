import Foundation

// ─────────────────────────────────────────────────────────
// WorkflowMatcher — find workflows applicable to the current goal
//
// Matches promoted workflow plans against the current goal
// text and selected strategy. Returns Match structs ranked
// by confidence (successRate × steps_quality) for the planner
// to use when selecting the workflowExecution strategy.
// ─────────────────────────────────────────────────────────

/// Matches promoted workflow plans to the current task context.
///
/// The planner calls `match(goal:index:strategy:)` at the start of
/// each planning cycle when the selected strategy is `.workflowExecution`
/// or when workflow reuse is being considered.
public struct WorkflowMatcher {

    public init() {}

    // MARK: – Match result

    /// A workflow match — a promoted plan with proposed next action types.
    public struct Match: Equatable {
        public let workflowID: String
        public let goalPattern: String
        public let proposedActionTypes: [String]
        public let confidence: Double

        public init(
            workflowID: String,
            goalPattern: String,
            proposedActionTypes: [String],
            confidence: Double
        ) {
            self.workflowID = workflowID
            self.goalPattern = goalPattern
            self.proposedActionTypes = proposedActionTypes
            self.confidence = confidence
        }
    }

    // MARK: – Primary API

    /// Find promoted workflows matching the current goal.
    ///
    /// - Parameters:
    ///   - goal: The current agent goal.
    ///   - index: The workflow catalogue.
    ///   - strategy: When non-nil, only workflows consistent with the
    ///     strategy kind are returned.
    /// - Returns: Matches sorted by descending confidence.
    public func match(
        goal: Goal,
        index: WorkflowIndex,
        strategy: SelectedStrategy? = nil
    ) -> [Match] {
        // Only consider promoted plans — candidates require promotion first (R10)
        let plans = index.matching(goal: goal).filter { $0.promotionStatus == .promoted }
        return plans.compactMap { plan -> Match? in
            // Optional strategy filter
            if let strategy = strategy {
                let inferredKind = StrategyKind.infer(fromSkills: plan.steps.map(\.skillName))
                let compatible = inferredKind == strategy.kind
                    || strategy.kind == .workflowExecution
                    || strategy.kind == .graphNavigation
                guard compatible else { return nil }
            }

            let actionTypes = plan.steps.prefix(6).map(\.actionType)
            guard !actionTypes.isEmpty else { return nil }

            // Base confidence: default 0.5 for plans with no recorded outcomes yet
            let baseConfidence = plan.attemptCount == 0 ? 0.5 : plan.successRate
            let confidence = baseConfidence * qualityFactor(plan: plan)
            return Match(
                workflowID: plan.id,
                goalPattern: plan.goalPattern,
                proposedActionTypes: Array(actionTypes),
                confidence: min(confidence, 1.0)
            )
        }
        .sorted { $0.confidence > $1.confidence }
    }

    // MARK: – Private

    /// Quality factor based on plan statistics (0.5 – 1.0).
    private func qualityFactor(plan: WorkflowPlan) -> Double {
        guard plan.attemptCount >= 3 else { return 0.5 }
        // More attempts + high success rate → higher quality
        let attemptFactor = min(Double(plan.attemptCount) / 10.0, 1.0)
        return 0.5 + 0.5 * attemptFactor
    }
}

// MARK: – StrategyKind inference from skill names

extension StrategyKind {
    /// Infer the strategy kind for a workflow based on its step skill names.
    fileprivate static func infer(fromSkills skills: [String]) -> StrategyKind {
        let hasRepair = skills.contains { $0.contains("test") || $0.contains("build") || $0.contains("patch") }
        let hasBrowser = skills.contains { $0.contains("browser") || $0.contains("navigate") || $0.contains("click") }
        if hasRepair { return .repoRepair }
        if hasBrowser { return .browserInteraction }
        return .graphNavigation
    }
}
