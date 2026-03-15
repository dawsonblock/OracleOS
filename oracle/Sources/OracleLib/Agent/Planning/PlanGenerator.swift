import Foundation

// ─────────────────────────────────────────────────────────
// PlanGenerator — the single planner entry point
//
// R1: The runtime calls exactly one planner API.
// All plan generators (reasoning, LLM, graph search) are
// internal helpers consumed by PlanGenerator, never called
// directly from the runtime.
//
// Pipeline:
//   goal + context → decompose → sequence → simulate → evaluate → plan
// ─────────────────────────────────────────────────────────

public struct Plan {

    public let id: String
    public let actions: [ActionIntent]
    public let goalID: String
    public let confidence: Double

    public init(
        actions: [ActionIntent],
        goalID: String = "",
        confidence: Double = 1.0,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.actions = actions
        self.goalID = goalID
        self.confidence = confidence
    }

    public static let empty = Plan(actions: [], goalID: "", confidence: 0)
}

// ─────────────────────────────────────────────────────────
// PlanningContext — what the planner reads
// ─────────────────────────────────────────────────────────

public struct PlanningContext {

    public let goal: Goal
    public let recentActions: [ExecutionTrace]
    public let memoryHints: [String]
    public let codeContext: [String]
    public let webContext: [String]

    public static func from(goal: Goal, assembledContext: String, recentTraces: [ExecutionTrace] = []) -> PlanningContext {
        return PlanningContext(
            goal: goal,
            recentActions: recentTraces,
            memoryHints: [assembledContext],
            codeContext: [],
            webContext: []
        )
    }
}

// ─────────────────────────────────────────────────────────
// PlanGenerator
// ─────────────────────────────────────────────────────────

public final class PlanGenerator {

    public let decomposer = ActionDecomposer()
    public let simulator = PlanSimulator()
    public let evaluator = PlanEvaluator()

    public init() {}

    public func generate(goal: Goal, context: String = "", recentTraces: [ExecutionTrace] = []) -> Plan {

        let planContext = PlanningContext.from(goal: goal, assembledContext: context, recentTraces: recentTraces)

        // 1. Decompose goal into action sequence
        let actions = decomposer.decompose(context: planContext)

        // 2. Build candidate plan
        let candidate = Plan(
            actions: actions,
            goalID: goal.id,
            confidence: 0.8
        )

        // 3. Simulate (dry run)
        let simResult = simulator.simulate(plan: candidate)
        guard simResult.feasible else {
            print("[planner] Plan simulation failed — returning empty plan")
            return Plan.empty
        }

        // 4. Evaluate/rank
        let scored = evaluator.score(plan: candidate, simulation: simResult)

        print("[planner] Generated plan with \(scored.actions.count) actions (confidence: \(scored.confidence))")

        return scored
    }
}

// ─────────────────────────────────────────────────────────
// ActionDecomposer — break goals into action sequences
// ─────────────────────────────────────────────────────────

public final class ActionDecomposer {

    public init() {}

    public func decompose(context: PlanningContext) -> [ActionIntent] {

        // Phase 3+: LLM-driven decomposition, graph-backed steps
        // Phase 0: single log action as proof of pipeline

        let action = ActionIntent(
            type: "log",
            domain: .system,
            parameters: ["message": "Processing: \(context.goal.description)"]
        )

        return [action]
    }
}

// ─────────────────────────────────────────────────────────
// GoalReducer — simplify compound goals
// ─────────────────────────────────────────────────────────

public final class GoalReducer {

    public init() {}

    public func reduce(goal: Goal) -> [Goal] {
        // Phase 3+: split compound goals
        return [goal]
    }
}
