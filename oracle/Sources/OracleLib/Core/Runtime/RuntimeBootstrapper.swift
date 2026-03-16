import Foundation

// ─────────────────────────────────────────────────────────
// RuntimeBootstrapper — subsystem construction factory
//
// Extracts all dependency wiring from OracleRuntime into a
// dedicated bootstrapper. OracleRuntime becomes a thin
// façade that holds references and delegates to AgentLoop.
//
// Blueprint ref: Gate 1, §1.11
// ─────────────────────────────────────────────────────────

/// Constructs and wires the full OracleRuntime subsystem graph.
public enum RuntimeBootstrapper {

    /// Wire all subsystem cross-references after OracleRuntime init.
    ///
    /// This replaces the monolithic `OracleRuntime.initialize()` body
    /// with a declarative bootstrapping pass. Each step is documented
    /// and can be unit-tested in isolation.
    public static func bootstrap(_ runtime: OracleRuntime) {

        print("[oracle] Runtime initializing")

        // ── 1. Persistence layer ────────────────────────
        runtime.memory.initialize()

        // ── 2. Execution truth boundary wiring ──────────
        runtime.executor.attachPolicy(runtime.policy)
        runtime.executor.attachTraceRecorder(runtime.traceRecorder)

        // ── 3. Action registry ──────────────────────────
        ActionRegistry.shared.registerDefaults()
        ShellTool.register(in: ActionRegistry.shared)

        // ── 4. Task graph initial position ──────────────
        runtime.taskGraph.updateCurrentNode(context: "idle")

        // ── 5. Search controller wiring ─────────────────
        runtime.searchController.attachCandidateGenerator(runtime.candidateGenerator)

        // ── 6. Warm lazy subsystems (triggers init) ─────
        _ = runtime.skillRegistry
        _ = runtime.stateCoordinator
        _ = runtime.decisionCoordinator
        _ = runtime.executionCoordinator
        _ = runtime.learningCoordinator
        _ = runtime.agentLoop
        _ = runtime.commandDispatcher

        // ── 7. Strategy layer ───────────────────────────
        _ = runtime.strategySelector
        _ = runtime.strategyEvaluator

        // ── 8. Workflow layer ───────────────────────────
        _ = runtime.workflowIndex
        _ = runtime.workflowMatcher

        // ── 9. Recovery layer ───────────────────────────
        _ = runtime.recoveryStrategyLibrary
        _ = runtime.recoveryStrategySelector

        // ── 10. Auxiliary subsystems ────────────────────
        _ = runtime.recipeStore
        _ = runtime.architectureEngine
        _ = runtime.memoryRouter
        _ = runtime.operatorRegistry
        _ = runtime.proposalEngine

        // ── 11. Diagnostics baseline ────────────────────
        runtime.diagnostics.attachMetrics(runtime.metrics)
        runtime.diagnostics.attachCritic(runtime.critic)
        runtime.diagnostics.printStatus()

        print("[oracle] Runtime ready")
    }
}
