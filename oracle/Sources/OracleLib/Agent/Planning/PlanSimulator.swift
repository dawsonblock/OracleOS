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

    public func simulate(plan: Plan, context: PlanningContext) -> SimulationResult {

        guard !plan.actions.isEmpty else {
            return SimulationResult.infeasible
        }

        var totalCost: Double = 0
        var warnings: [String] = []
        var feasible = true

        // Phase 1 Simulation Constraints
        for action in plan.actions {
            // 1. Calculate operational cost based on domain
            switch action.domain {
            case .browser, .host:
                totalCost += 5.0
            case .code, .tool:
                totalCost += 3.0
            case .search:
                totalCost += 2.0
            case .system:
                totalCost += 1.0
            }

            // 2. Check memory for identical recent failures
            // R2 Rule: If something consistently failed, warn or block repetition.
            let previousFailures = context.recentActions.filter {
                $0.actionType == action.type && !$0.success
            }
            if previousFailures.count > 2 {
                warnings.append("High risk: Action type \(action.type) has failed \(previousFailures.count) times recently.")
                feasible = false
            }
        }

        // Bounded constraint check
        if totalCost > 50.0 {
            warnings.append("Cost exceeds nominal threshold (50.0).")
        }
        
        let cycleDetected =  Set(plan.actions.map { $0.type }).count < plan.actions.count
        if cycleDetected {
            warnings.append("Actions contain redundant loops.")
        }

        return SimulationResult(
            feasible: feasible,
            estimatedCost: totalCost,
            estimatedSteps: plan.actions.count,
            warnings: warnings
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
        
        guard simulation.feasible else {
            return Plan.empty
        }

        // Base confidence derived from simulation constraints
        var confidence = 1.0

        // Subtractive heuristcs 
        confidence -= (simulation.estimatedCost * 0.02)  // Cost penalty
        confidence -= Double(simulation.warnings.count) * 0.1 // Warnings penalty
        
        // Floor constraints
        confidence = max(0.1, min(confidence, 1.0))

        return Plan(
            actions: plan.actions,
            goalID: plan.goalID,
            confidence: confidence,
            id: plan.id
        )
    }
}
