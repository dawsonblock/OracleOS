import Foundation

// ─────────────────────────────────────────────────────────
// PlanSimulator — simulate plans before commitment
//
// Protected backbone module. May be strengthened but not
// bypassed, duplicated, or replaced.
// ─────────────────────────────────────────────────────────

public struct SimulationResult {

    public let feasible: Bool
    public let estimatedCost: Double
    public let estimatedSteps: Int
    public let warnings: [String]

    public static let infeasible = SimulationResult(
        feasible: false, estimatedCost: 0, estimatedSteps: 0, warnings: ["infeasible"]
    )
}

public final class PlanSimulator {

    public init() {}

    public func simulate(plan: Plan) -> SimulationResult {

        guard !plan.actions.isEmpty else {
            return SimulationResult.infeasible
        }

        // Phase 3+: validate action preconditions, check resource requirements
        // Phase 0: accept all non-empty plans

        return SimulationResult(
            feasible: true,
            estimatedCost: Double(plan.actions.count),
            estimatedSteps: plan.actions.count,
            warnings: []
        )
    }
}

// ─────────────────────────────────────────────────────────
// PlanEvaluator — sole ranking authority
// ─────────────────────────────────────────────────────────

public final class PlanEvaluator {

    public init() {}

    public func score(plan: Plan, simulation: SimulationResult) -> Plan {

        // Phase 3+: rank competing plans by:
        //   success probability, estimated cost, step count, risk

        let confidence = simulation.feasible ? 0.8 : 0.0

        return Plan(
            actions: plan.actions,
            goalID: plan.goalID,
            confidence: confidence,
            id: plan.id
        )
    }
}
