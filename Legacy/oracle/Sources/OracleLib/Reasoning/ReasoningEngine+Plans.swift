import Foundation

// MARK: - ReasoningEngine + Operator-based plan generation

/// Extends the existing `ReasoningEngine` with operator-driven plan generation
/// using the Reasoning layer's `ReasoningPlanningState` and `PlanCandidate` types.
extension ReasoningEngine {

    /// Generate candidate plans from a reasoning planning state using operator expansion.
    ///
    /// - Parameter state: The current reasoning planning state.
    /// - Returns: An array of `PlanCandidate` values, sorted by operator sequence length.
    public func generatePlans(from state: ReasoningPlanningState) -> [PlanCandidate] {
        generatePlans(
            from: state,
            maxDepth: 3,
            maxPlans: 5,
            operatorRegistry: .shared
        )
    }

    /// Generate candidate plans with explicit control parameters.
    public func generatePlans(
        from state: ReasoningPlanningState,
        maxDepth: Int,
        maxPlans: Int,
        operatorRegistry: OperatorRegistry
    ) -> [PlanCandidate] {
        var plans: [PlanCandidate] = []
        var seen: Set<[ReasoningOperatorKind]> = []
        expandPlans(
            state: state,
            current: [],
            depth: 0,
            maxDepth: maxDepth,
            maxPlans: maxPlans,
            operatorRegistry: operatorRegistry,
            plans: &plans,
            seen: &seen
        )
        return plans
    }

    // MARK: - Private expansion

    private func expandPlans(
        state: ReasoningPlanningState,
        current: [Operator],
        depth: Int,
        maxDepth: Int,
        maxPlans: Int,
        operatorRegistry: OperatorRegistry,
        plans: inout [PlanCandidate],
        seen: inout Set<[ReasoningOperatorKind]>
    ) {
        guard plans.count < maxPlans else { return }

        if !current.isEmpty {
            let kinds = current.map(\.kind)
            if seen.insert(kinds).inserted {
                plans.append(PlanCandidate(operators: current, projectedState: state))
            }
        }

        guard depth < maxDepth else { return }

        let available = operatorRegistry.available(for: state)
        for op in available {
            if current.last?.kind == op.kind { continue }

            let newState = op.effect(state)
            guard newState != state else { continue }

            expandPlans(
                state: newState,
                current: current + [op],
                depth: depth + 1,
                maxDepth: maxDepth,
                maxPlans: maxPlans,
                operatorRegistry: operatorRegistry,
                plans: &plans,
                seen: &seen
            )

            if plans.count >= maxPlans { return }
        }
    }
}
