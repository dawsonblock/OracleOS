import Foundation

// ─────────────────────────────────────────────────────────
// DecisionCoordinator — sole planner façade for the runtime loop
//
// `DecisionCoordinator` is the ONLY path from the runtime into
// the planning subsystem. It routes each loop step through
// PlanGenerator, consulting state memory for known-good patterns
// before generating a new plan.
//
// Architecture rule: this coordinator PLANS but never EXECUTES.
// Execution is always performed by VerifiedActionExecutor.
// ─────────────────────────────────────────────────────────

/// Façade over the planning subsystem.
///
/// The runtime loop calls `decide(from:assembledContext:)` each step.
/// `DecisionCoordinator` is responsible for:
///   1. Consulting `StateMemoryIndex` for known-good action patterns.
///   2. Enriching context with memory hints before calling the planner.
///   3. Delegating to `PlanGenerator` and returning the resulting `Plan`.
///
/// - Important: This coordinator plans but never executes.
public final class DecisionCoordinator {

    // ── Dependencies ────────────────────────────────────

    private let planner: PlanGenerator
    private let graphStore: GraphStore
    private let stateMemory: StateMemoryIndex

    // ── Init ────────────────────────────────────────────

    public init(
        planner: PlanGenerator,
        graphStore: GraphStore,
        stateMemory: StateMemoryIndex
    ) {
        self.planner = planner
        self.graphStore = graphStore
        self.stateMemory = stateMemory
    }

    // MARK: – Planning

    /// Generate a plan for the current state bundle.
    ///
    /// Checks state memory for a remembered pattern. If found, the
    /// likely actions are surfaced as a context hint so the planner
    /// can replay the successful sequence directly. Falls back to
    /// unconstrained planning when no pattern is known.
    ///
    /// - Parameters:
    ///   - bundle: The current agent state as produced by `StateCoordinator`.
    ///   - assembledContext: Additional context text (code snippets, web info, etc.).
    /// - Returns: A `Plan` ready for policy evaluation and execution.
    public func decide(from bundle: StateBundle, assembledContext: String = "") -> Plan {
        let goal = bundle.taskContext.goal
        let recentTraces = graphStore.recentTraces(limit: 5)

        // Consult state memory for known patterns.
        let sig = StateSignature.from(
            context: goal.description + assembledContext,
            actionTypes: []
        )
        let knownActions = stateMemory.likelyActions(for: sig)

        let contextWithHints: String
        if knownActions.isEmpty {
            contextWithHints = assembledContext
        } else {
            let hint = "[memory] Likely actions: " + knownActions.joined(separator: ", ")
            contextWithHints = assembledContext.isEmpty ? hint : assembledContext + "\n" + hint
        }

        return planner.generate(
            goal: goal,
            context: contextWithHints,
            recentTraces: recentTraces
        )
    }

    // MARK: – Goal termination

    /// Determine whether the goal has been reached.
    ///
    /// - Note: Currently a stub that always returns `false`.
    ///   Full postcondition-based goal detection is implemented
    ///   in a subsequent step together with `PostconditionVerifier`.
    public func isGoalReached(bundle: StateBundle) -> Bool {
        // Phase: postcondition-based detection.
        // The runtime drives termination via critic verdict + step budget.
        return false
    }
}
