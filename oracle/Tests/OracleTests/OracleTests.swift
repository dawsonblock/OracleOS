import XCTest
@testable import OracleLib

// ═══════════════════════════════════════════════════════════
// OracleTests — comprehensive test suite for the Oracle runtime
//
// Tests cover:
//   1. Core execution spine (R4 — VerifiedActionExecutor)
//   2. Memory truth store (R2 — GraphStore)
//   3. Planning pipeline (R1 — single entry)
//   4. Policy engine (gating + risk evaluation)
//   5. Context assembly + prompt building
//   6. Action registry + dispatch
//   7. Trace recording
//   8. MCP tool registry
//   9. Goal & Intent creation
//  10. Event bus
//  11. Prompt engine
//  12. Integration: full pipeline
//  13. Diagnostics
//  14. Search
//  15. Browser automation
// ═══════════════════════════════════════════════════════════

// MARK: - 1. VerifiedActionExecutor Tests

final class VerifiedActionExecutorTests: XCTestCase {

    func testExecuteRegisteredAction() {
        let executor = VerifiedActionExecutor()
        let policy = PolicyEngine()
        let recorder = TraceRecorder()
        executor.attachPolicy(policy)
        executor.attachTraceRecorder(recorder)

        ActionRegistry.shared.register("test_action") { _ in
            return ExecutionResult(success: true, detail: "test passed")
        }

        let action = ActionIntent(type: "test_action", domain: .system, parameters: [:])
        let result = executor.execute(action: action)

        XCTAssertTrue(result.success, "Registered action should succeed")
        XCTAssertTrue(result.executedThroughExecutor, "R4: must be stamped by executor")
    }

    func testExecuteUnregisteredAction() {
        let executor = VerifiedActionExecutor()
        let policy = PolicyEngine()
        executor.attachPolicy(policy)

        let action = ActionIntent(type: "nonexistent_action_xyz", domain: .system, parameters: [:])
        let result = executor.execute(action: action)

        XCTAssertFalse(result.success, "Unregistered action should fail")
    }

    func testAllResultsStamped() {
        let executor = VerifiedActionExecutor()
        let policy = PolicyEngine()
        executor.attachPolicy(policy)

        ActionRegistry.shared.register("stamp_test") { _ in
            return ExecutionResult(success: true, detail: "ok")
        }

        let action = ActionIntent(type: "stamp_test", domain: .system, parameters: [:])
        let result = executor.execute(action: action)

        XCTAssertTrue(result.executedThroughExecutor, "R4: All results must be stamped")
    }
}

// MARK: - 2. GraphStore Tests

final class GraphStoreTests: XCTestCase {

    func testInitialize() {
        let store = GraphStore()
        store.initialize()
    }

    func testRecordAndRetrieve() {
        let store = GraphStore()
        store.initialize()

        let action = ActionIntent(type: "test_write", domain: .system, parameters: ["key": "value"])
        let result = ExecutionResult(success: true, detail: "written")
        store.record(result: result, forAction: action)

        let traces = store.recentTraces(limit: 20)
        XCTAssertFalse(traces.isEmpty, "Should have at least one trace after recording")
        XCTAssertTrue(traces.contains(where: { $0.actionType == "test_write" }), "Should contain the recorded test_write trace")
    }

    func testAddNode() {
        let store = GraphStore()
        store.initialize()

        let nodeID = store.addNode(type: "test", label: "test_node", data: "payload")
        XCTAssertFalse(nodeID.isEmpty, "Node ID should not be empty")
    }

    func testGoalRecording() {
        let store = GraphStore()
        store.initialize()

        let goal = Goal(description: "test goal")
        store.recordGoal(goal)
    }
}

// MARK: - 3. Planning Pipeline Tests

final class PlanGeneratorTests: XCTestCase {

    func testGeneratePlan() {
        let planner = PlanGenerator()
        let goal = Goal(description: "read a file")
        let plan = planner.generate(goal: goal, context: "reading context")

        XCTAssertFalse(plan.actions.isEmpty, "Plan should have at least one action")
        XCTAssertGreaterThan(plan.confidence, 0, "Confidence should be positive")
        XCTAssertEqual(plan.goalID, goal.id)
    }

    func testPlanSimulation() {
        let simulator = PlanSimulator()
        let goal = Goal(description: "simple task")
        let planner = PlanGenerator()
        let plan = planner.generate(goal: goal, context: "context")

        let sim = simulator.simulate(plan: plan, context: PlanningContext.from(goal: goal, assembledContext: "context", recentTraces: []))
        XCTAssertTrue(sim.feasible, "Simple plan should be feasible")
    }
}

// MARK: - 4. Policy Engine Tests

final class PolicyEngineTests: XCTestCase {

    func testDefaultAllowlist() {
        let policy = PolicyEngine()
        let action = ActionIntent(type: "read_file", domain: .system, parameters: [:])
        XCTAssertTrue(policy.allow(action: action), "Default policy should allow system actions")
    }

    func testRiskEvaluation() {
        let low = RiskEvaluator.evaluate(action: ActionIntent(type: "read_file", domain: .system, parameters: [:]))
        XCTAssertTrue(low == .safe || low == .low, "read_file should be low risk")
    }

    func testSandboxRouting() {
        let policy = PolicyEngine()
        let lowAction = ActionIntent(type: "log", domain: .system, parameters: [:])
        XCTAssertFalse(policy.requiresSandbox(action: lowAction), "Low risk should not require sandbox")
    }
}

// MARK: - 5. Context Assembly Tests

final class ContextAssemblerTests: XCTestCase {

    func testAssembleWithGoal() {
        let store = GraphStore()
        store.initialize()
        let codeQuery = CodeQueryEngine()
        let retriever = ContextRetriever()

        let assembler = ContextAssembler(graphStore: store, codeQuery: codeQuery, retriever: retriever)
        let goal = Goal(description: "test goal")

        let assembled = assembler.assemble(goal: goal, plan: nil)

        XCTAssertFalse(assembled.text.isEmpty, "Assembled context should not be empty")
        XCTAssertTrue(assembled.text.contains("test goal"), "Context should contain goal")
        XCTAssertGreaterThan(assembled.estimatedTokens, 0)
    }

    func testTokenBudgetManager() {
        let mgr = TokenBudgetManager()
        let estimate = mgr.estimate(text: "hello world")
        XCTAssertGreaterThan(estimate, 0, "Token estimate should be positive")
    }
}

// MARK: - 6. Action Registry Tests

final class ActionRegistryTests: XCTestCase {

    func testRegisterDefaults() {
        let registry = ActionRegistry.shared
        registry.registerDefaults()

        let actions = registry.registeredActions()
        XCTAssertTrue(actions.contains("log"), "Should have log action")
        XCTAssertTrue(actions.contains("read_file"), "Should have read_file action")
        XCTAssertTrue(actions.contains("write_file"), "Should have write_file action")
    }

    func testCustomRegistration() {
        let registry = ActionRegistry.shared
        registry.register("custom_test_action") { _ in
            return ExecutionResult(success: true, detail: "custom")
        }
        XCTAssertTrue(registry.registeredActions().contains("custom_test_action"))
    }

    func testExecuteRegistered() {
        let registry = ActionRegistry.shared
        registry.registerDefaults()

        let action = ActionIntent(type: "log", domain: .system, parameters: ["message": "hello"])
        let handler = registry.handler(for: "log")
        let result = handler(action)
        XCTAssertTrue(result.success, "Registered action should succeed")
    }

    func testExecuteUnregistered() {
        let registry = ActionRegistry.shared
        XCTAssertFalse(registry.isRegistered("this_does_not_exist_xyz"), "Unregistered action should not be found")
    }
}

// MARK: - 7. Trace Recording Tests

final class TraceRecorderTests: XCTestCase {

    func testRecordAndRetrieve() {
        let recorder = TraceRecorder()
        let action = ActionIntent(type: "test", domain: .system, parameters: [:])
        let event = TraceEvent(action: action, outcome: .success, detail: "passed")
        recorder.record(event)

        XCTAssertEqual(recorder.eventCount(), 1)
        XCTAssertEqual(recorder.recentEvents().count, 1)
        XCTAssertEqual(recorder.recentEvents().first?.outcome, .success)
    }

    func testEventFiltering() {
        let recorder = TraceRecorder()
        let a1 = ActionIntent(type: "read", domain: .system, parameters: [:])
        let a2 = ActionIntent(type: "write", domain: .system, parameters: [:])

        recorder.record(TraceEvent(action: a1, outcome: .success))
        recorder.record(TraceEvent(action: a2, outcome: .failure, detail: "denied"))
        recorder.record(TraceEvent(action: a1, outcome: .success))

        let reads = recorder.eventsForAction(type: "read")
        XCTAssertEqual(reads.count, 2)
    }
}

// MARK: - 8. MCP Tool Registry Tests

final class MCPServerTests: XCTestCase {

    func testToolRegistration() {
        let registry = MCPToolRegistry()
        registry.registerDefaults()

        XCTAssertGreaterThan(registry.toolCount(), 10, "Should have 16+ default tools")
    }

    func testToolLookup() {
        let registry = MCPToolRegistry()
        registry.registerDefaults()

        let tool = registry.tool(named: "oracle_click")
        XCTAssertNotNil(tool)
        XCTAssertEqual(tool?.actionType, "click_element")
    }

    func testMCPServerHandleRequest() {
        let server = MCPServer()
        server.start(port: 0)

        let response = server.handleRequest(toolName: "oracle_click", parameters: ["target": "button"])
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.actionIntent)
    }

    func testMCPServerUnknownTool() {
        let server = MCPServer()
        server.start(port: 0)

        let response = server.handleRequest(toolName: "nonexistent_tool", parameters: [:])
        XCTAssertFalse(response.success)
    }
}

// MARK: - 9. Goal & Intent Tests

final class GoalTests: XCTestCase {

    func testGoalCreation() {
        let goal = Goal(description: "do something")
        XCTAssertFalse(goal.id.isEmpty)
        XCTAssertEqual(goal.description, "do something")
        XCTAssertEqual(goal.priority, .normal)
    }

    func testActionIntentCreation() {
        let intent = ActionIntent(type: "click", domain: .host, parameters: ["target": "btn"])
        XCTAssertEqual(intent.type, "click")
        XCTAssertEqual(intent.domain, .host)
        XCTAssertEqual(intent.parameters["target"], "btn")
    }

    func testExecutionResultStatic() {
        let blocked = ExecutionResult.blocked(actionID: "123", reason: "denied")
        XCTAssertFalse(blocked.success)
        XCTAssertFalse(blocked.executedThroughExecutor)
        XCTAssertTrue(blocked.detail.contains("BLOCKED"))
    }
}

// MARK: - 10. Event Bus Tests

final class EventBusTests: XCTestCase {

    func testEmitAndSubscribe() {
        let bus = EventBus()
        var received = false

        bus.subscribe { event in
            if case .goalCompleted = event {
                received = true
            }
        }

        let goal = Goal(description: "test")
        bus.emit(.goalCompleted(goal))

        XCTAssertTrue(received, "Subscriber should receive emitted event")
    }
}

// MARK: - 11. Prompt Engine Tests

final class PromptBuilderTests: XCTestCase {

    func testBuildPrompt() {
        let builder = PromptBuilder()
        let context = ContextAssembler.AssembledContext(
            text: "Goal: test\nContext: unit test",
            estimatedTokens: 10,
            sections: ["test"]
        )

        let prompt = builder.build(template: .plan, context: context)
        XCTAssertTrue(prompt.contains("Oracle"), "Prompt should mention Oracle")
        XCTAssertTrue(prompt.contains("test"), "Prompt should contain context")
    }

    func testPromptCache() {
        let cache = PromptCache()
        cache.set(prompt: "test_key", response: "cached_response")

        let hit = cache.get(prompt: "test_key")
        XCTAssertEqual(hit, "cached_response")

        let miss = cache.get(prompt: "nonexistent")
        XCTAssertNil(miss)
    }
}

// MARK: - 12. Integration: Full Pipeline

final class PipelineIntegrationTests: XCTestCase {

    func testGoalToTrace() {
        let runtime = OracleRuntime()
        runtime.initialize()

        ActionRegistry.shared.register("analyze") { action in
            return ExecutionResult(success: true, detail: "analyzed: \(action.parameters)")
        }

        let goal = Goal(description: "analyze the system")
        runtime.process(goal: goal)

        let events = runtime.traceRecorder.recentEvents()
        XCTAssertGreaterThan(events.count, 0, "Processing a goal should produce trace events")
    }

    func testRuntimeVersion() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertEqual(runtime.version, "0.1.0")
    }
}

// MARK: - 13. Diagnostics Tests

final class DiagnosticsTests: XCTestCase {

    func testDashboardSnapshot() {
        let recorder = TraceRecorder()
        let bus = EventBus()
        let dashboard = SystemDashboard(traceRecorder: recorder, eventBus: bus)

        let snap = dashboard.snapshot()
        XCTAssertEqual(snap.totalActions, 0)
        XCTAssertEqual(snap.successRate, 1.0)
        XCTAssertGreaterThanOrEqual(snap.uptime, 0)
    }

    func testTraceVisualizer() {
        let viz = TraceVisualizer()
        let empty = viz.render(traces: [])
        XCTAssertEqual(empty, "(no traces)")
    }

    func testPerformanceMonitor() {
        let monitor = PerformanceMonitor()
        let _ = monitor.measure(label: "test_op") {
            // Simulate some work
            let _ = (0..<100).reduce(0, +)
        }
        let summary = monitor.summary()
        XCTAssertFalse(summary.isEmpty, "Summary should contain measurement data")
    }
}

// MARK: - 14. Search Tests

final class SearchTests: XCTestCase {

    func testSearchRanking() {
        let ranker = SearchRanking()
        let results = [
            SearchController.SearchResult(source: "code", title: "a", snippet: "low", url: "code://a", timestamp: Date(), relevance: 0.2),
            SearchController.SearchResult(source: "web", title: "b", snippet: "high", url: "web://b", timestamp: Date(), relevance: 0.9),
            SearchController.SearchResult(source: "graph", title: "c", snippet: "mid", url: "graph://c", timestamp: Date(), relevance: 0.5),
        ]
        let ranked = ranker.rank(results, query: "high")
        XCTAssertEqual(ranked.first?.title, "b", "Highest score should rank first")
    }
}

// MARK: - 15. Browser Automation Tests

final class BrowserTests: XCTestCase {

    func testPageSnapshot() {
        let snap = PageSnapshot(url: "https://example.com", html: "<p>hi</p>", timestamp: Date())
        XCTAssertEqual(snap.url, "https://example.com")
        XCTAssertTrue(snap.html.contains("<p>"), "HTML should be stored")
    }

    func testBrowserTargetResolver() {
        let resolver = BrowserTargetResolver()
        let target = resolver.resolve(target: "btn-submit", in: nil)
        XCTAssertEqual(target.id, "btn-submit")
        XCTAssertEqual(target.method, .domID)
    }
}

// MARK: - 16. ActionDecomposer Classification Tests

final class ActionDecomposerTests: XCTestCase {

    func testClassifyReadFile() {
        let decomposer = ActionDecomposer()
        let goal = Goal(description: "read file /tmp/test.txt")
        XCTAssertEqual(decomposer.classify(goal: goal), .readFile)
    }

    func testClassifyBuild() {
        let decomposer = ActionDecomposer()
        let goal = Goal(description: "build the project")
        XCTAssertEqual(decomposer.classify(goal: goal), .buildProject)
    }

    func testClassifyRunTests() {
        let decomposer = ActionDecomposer()
        let goal = Goal(description: "run tests in workspace")
        XCTAssertEqual(decomposer.classify(goal: goal), .runTests)
    }

    func testClassifySearch() {
        let decomposer = ActionDecomposer()
        let goal = Goal(description: "search for GraphStore usage")
        XCTAssertEqual(decomposer.classify(goal: goal), .search)
    }

    func testClassifyBrowse() {
        let decomposer = ActionDecomposer()
        let goal = Goal(description: "browse https://example.com")
        XCTAssertEqual(decomposer.classify(goal: goal), .browse)
    }

    func testClassifyUnknown() {
        let decomposer = ActionDecomposer()
        let goal = Goal(description: "xyzzy foobar")
        XCTAssertEqual(decomposer.classify(goal: goal), .unknown)
    }

    func testDecomposeProducesMultipleActions() {
        let decomposer = ActionDecomposer()
        let context = PlanningContext.from(goal: Goal(description: "read file /tmp/a.txt"), assembledContext: "")
        let actions = decomposer.decompose(context: context)
        XCTAssertEqual(actions.count, 2, "read_file should produce log + read")
        XCTAssertEqual(actions[0].type, "log")
        XCTAssertEqual(actions[1].type, "read_file")
    }

    func testDecomposeEditProducesThreeActions() {
        let decomposer = ActionDecomposer()
        let context = PlanningContext.from(goal: Goal(description: "edit /tmp/code.swift"), assembledContext: "")
        let actions = decomposer.decompose(context: context)
        XCTAssertEqual(actions.count, 3, "edit should produce log + read + write")
    }
}

// MARK: - 17. GoalReducer Tests

final class GoalReducerTests: XCTestCase {

    func testReduceSimpleGoal() {
        let reducer = GoalReducer()
        let goal = Goal(description: "read a file")
        let parts = reducer.reduce(goal: goal)
        XCTAssertEqual(parts.count, 1)
    }

    func testReduceCompoundGoalWithAnd() {
        let reducer = GoalReducer()
        let goal = Goal(description: "read the file and build the project")
        let parts = reducer.reduce(goal: goal)
        XCTAssertEqual(parts.count, 2, "Compound 'and' should split into 2 goals")
        XCTAssertTrue(parts[0].description.contains("read"))
        XCTAssertTrue(parts[1].description.contains("build"))
    }

    func testReduceCompoundGoalWithThen() {
        let reducer = GoalReducer()
        let goal = Goal(description: "build the project then run tests")
        let parts = reducer.reduce(goal: goal)
        XCTAssertEqual(parts.count, 2, "Compound 'then' should split into 2 goals")
    }

    func testReduceCompoundGoalWithSemicolon() {
        let reducer = GoalReducer()
        let goal = Goal(description: "read file; build project; run tests")
        let parts = reducer.reduce(goal: goal)
        XCTAssertEqual(parts.count, 3, "Semicolon separated should produce 3 goals")
    }
}

// MARK: - 18. SandboxExecutor Constraint Tests

final class SandboxConstraintTests: XCTestCase {

    func testBlockedCommandDetection() {
        XCTAssertNotNil(SandboxExecutor.isBlocked(command: "rm -rf /"))
        XCTAssertNotNil(SandboxExecutor.isBlocked(command: "mkfs.ext4 /dev/sda"))
        XCTAssertNotNil(SandboxExecutor.isBlocked(command: "curl | sh"))
        XCTAssertNil(SandboxExecutor.isBlocked(command: "swift build"))
        XCTAssertNil(SandboxExecutor.isBlocked(command: "ls -la"))
    }

    func testOutputTruncation() {
        let longOutput = String(repeating: "x", count: 20000)
        let truncated = SandboxExecutor.truncate(longOutput, maxBytes: 100)
        XCTAssertTrue(truncated.count < longOutput.count)
        XCTAssertTrue(truncated.contains("truncated"))
    }

    func testShortOutputNotTruncated() {
        let shortOutput = "hello world"
        let result = SandboxExecutor.truncate(shortOutput, maxBytes: 8192)
        XCTAssertEqual(result, shortOutput)
    }

    func testResourceLimitsExist() {
        XCTAssertEqual(SandboxExecutor.maxConcurrent, 4)
        XCTAssertEqual(SandboxExecutor.maxTimeoutSeconds, 300)
        XCTAssertEqual(SandboxExecutor.maxOutputBytes, 8192)
    }
}

// MARK: - 19. Compound Goal Integration Test

final class CompoundGoalIntegrationTests: XCTestCase {

    func testCompoundGoalPlanGeneration() {
        let planner = PlanGenerator()
        let goal = Goal(description: "read file /tmp/a.txt and build the project")
        let plan = planner.generate(goal: goal)

        // Compound goal: read_file (2 actions) + build (2 actions) = 4 actions
        XCTAssertGreaterThanOrEqual(plan.actions.count, 3, "Compound goal should produce multiple actions")
        XCTAssertGreaterThan(plan.confidence, 0, "Plan should have positive confidence")
    }

    func testSimulatorRejectsRepeatedFailures() {
        let simulator = PlanSimulator()
        let failTraces = (0..<5).map { _ in
            ExecutionTrace(
                actionID: UUID().uuidString,
                actionType: "shell_command",
                preStateHash: "pre",
                postStateHash: "post",
                verified: false,
                success: false
            )
        }
        let goal = Goal(description: "run command ls")
        let context = PlanningContext.from(goal: goal, assembledContext: "", recentTraces: failTraces)
        let plan = Plan(actions: [
            ActionIntent(type: "shell_command", domain: .tool, parameters: ["command": "ls"])
        ], goalID: goal.id)

        let result = simulator.simulate(plan: plan, context: context)
        XCTAssertFalse(result.feasible, "Simulator should reject action type with >2 recent failures")
        XCTAssertFalse(result.warnings.isEmpty, "Should produce warnings for repeated failures")
    }
}

// MARK: - 20. CriticLoop Tests

final class CriticLoopTests: XCTestCase {

    func testSuccessfulReadOnlyAction() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "log", domain: .system)
        let result = ExecutionResult(success: true, detail: "ok", actionID: action.id)
        let eval = critic.evaluate(action: action, result: result, preStateHash: "a", postStateHash: "a")
        XCTAssertEqual(eval.verdict, .success, "Read-only success should be .success")
        XCTAssertGreaterThan(eval.confidence, 0.8)
    }

    func testSuccessfulWriteActionWithStateChange() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "write_file", domain: .code)
        let result = ExecutionResult(success: true, detail: "written", actionID: action.id)
        let eval = critic.evaluate(action: action, result: result, preStateHash: "pre", postStateHash: "post")
        XCTAssertEqual(eval.verdict, .success, "Write action with state change should be .success")
        XCTAssertTrue(eval.stateChanged)
    }

    func testFailedActionNoStateChange() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "write_file", domain: .code)
        let result = ExecutionResult(success: false, detail: "denied", actionID: action.id)
        let eval = critic.evaluate(action: action, result: result, preStateHash: "same", postStateHash: "same")
        XCTAssertEqual(eval.verdict, .failure)
        XCTAssertFalse(eval.stateChanged)
    }

    func testFailedActionWithStateChange() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "write_file", domain: .code)
        let result = ExecutionResult(success: false, detail: "partial write", actionID: action.id)
        let eval = critic.evaluate(action: action, result: result, preStateHash: "pre", postStateHash: "post")
        XCTAssertEqual(eval.verdict, .partialSuccess, "Failed but state changed → partialSuccess")
    }

    func testSuccessNoStateChangeIsUnknown() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "write_file", domain: .code)
        let result = ExecutionResult(success: true, detail: "ok", actionID: action.id)
        let eval = critic.evaluate(action: action, result: result, preStateHash: "same", postStateHash: "same")
        XCTAssertEqual(eval.verdict, .unknown, "Write success with no state change → unknown")
    }

    func testTrustBoundaryViolation() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "write_file", domain: .code)
        let result = ExecutionResult(success: true, detail: "bypass", executedThroughExecutor: false, actionID: action.id)
        let eval = critic.evaluate(action: action, result: result, preStateHash: "a", postStateHash: "b")
        XCTAssertEqual(eval.verdict, .failure, "Bypassed executor should always be .failure")
        XCTAssertEqual(eval.confidence, 1.0)
    }

    func testSuccessRateTracking() {
        let critic = CriticLoop()
        // 2 successes (read-only 'log' action), 1 failure
        let logAction = ActionIntent(type: "log", domain: .system)
        _ = critic.evaluate(action: logAction, result: ExecutionResult(success: true, detail: "", actionID: "a"), preStateHash: "a", postStateHash: "a")
        _ = critic.evaluate(action: logAction, result: ExecutionResult(success: true, detail: "", actionID: "b"), preStateHash: "a", postStateHash: "a")
        let failAction = ActionIntent(type: "write_file", domain: .code)
        _ = critic.evaluate(action: failAction, result: ExecutionResult(success: false, detail: "err", actionID: "c"), preStateHash: "x", postStateHash: "x")

        let rate = critic.overallSuccessRate()
        XCTAssertGreaterThan(rate, 0, "Should have nonzero success rate")
        XCTAssertLessThan(rate, 1.0, "Should not be 100% with a failure")
    }

    func testShouldRecommendRecovery() {
        let critic = CriticLoop()
        let action = ActionIntent(type: "test_action", domain: .tool)

        // Add 5 failures
        for _ in 0..<5 {
            _ = critic.evaluate(
                action: action,
                result: ExecutionResult(success: false, detail: "err", actionID: UUID().uuidString),
                preStateHash: "same",
                postStateHash: "same"
            )
        }

        XCTAssertTrue(critic.shouldRecommendRecovery(), "5 consecutive failures should trigger recovery recommendation")
    }
}

// MARK: - 21. RecoveryCoordinator Tests

final class RecoveryCoordinatorTests: XCTestCase {

    func testRetryOnFailure() {
        let recovery = RecoveryCoordinator()
        let action = ActionIntent(type: "write_file", domain: .code)
        let eval = CriticEvaluation(
            actionID: action.id, actionType: action.type,
            verdict: .failure, confidence: 0.9,
            preStateHash: "pre", postStateHash: "pre",
            stateChanged: false, detail: "write failed"
        )

        let decision = recovery.recover(action: action, evaluation: eval, goalID: "goal-1")
        if case .retry(let retryAction) = decision {
            XCTAssertEqual(retryAction.type, "write_file")
            XCTAssertNotNil(retryAction.parameters["_recovery_attempt"])
        } else {
            XCTFail("First failure should trigger retry, got: \(decision)")
        }
    }

    func testSkipOnPartialSuccess() {
        let recovery = RecoveryCoordinator()
        let action = ActionIntent(type: "write_file", domain: .code)
        let eval = CriticEvaluation(
            actionID: action.id, actionType: action.type,
            verdict: .partialSuccess, confidence: 0.5,
            preStateHash: "pre", postStateHash: "post",
            stateChanged: true, detail: "partial"
        )

        let decision = recovery.recover(action: action, evaluation: eval, goalID: "goal-2")
        if case .skip = decision {
            // expected
        } else {
            XCTFail("Partial success should skip, got: \(decision)")
        }
    }

    func testMaxRetriesExhausted() {
        let recovery = RecoveryCoordinator()
        let action = ActionIntent(type: "write_file", domain: .code, id: "fixed-id")
        let eval = CriticEvaluation(
            actionID: action.id, actionType: action.type,
            verdict: .failure, confidence: 0.9,
            preStateHash: "pre", postStateHash: "pre",
            stateChanged: false, detail: "fail"
        )

        // Use up retry budget (2 retries max)
        _ = recovery.recover(action: action, evaluation: eval, goalID: "goal-3")
        _ = recovery.recover(action: action, evaluation: eval, goalID: "goal-3")

        let decision = recovery.recover(action: action, evaluation: eval, goalID: "goal-3")
        if case .skip = decision {
            // expected — retries exhausted for this action
        } else {
            XCTFail("After max retries should skip, got: \(decision)")
        }
    }

    func testGoalBudgetExhausted() {
        let recovery = RecoveryCoordinator()
        let eval = CriticEvaluation(
            actionID: "x", actionType: "test",
            verdict: .failure, confidence: 0.9,
            preStateHash: "pre", postStateHash: "pre",
            stateChanged: false, detail: "fail"
        )

        // Exhaust goal budget (5 attempts max) with different action IDs
        for i in 0..<5 {
            let action = ActionIntent(type: "test", domain: .tool, id: "action-\(i)")
            _ = recovery.recover(action: action, evaluation: eval, goalID: "goal-4")
        }

        // 6th attempt should abort
        let action = ActionIntent(type: "test", domain: .tool, id: "action-new")
        let decision = recovery.recover(action: action, evaluation: eval, goalID: "goal-4")
        if case .abort = decision {
            // expected — goal budget exhausted
        } else {
            XCTFail("After 5 recovery attempts per goal should abort, got: \(decision)")
        }
    }

    func testClearStateResetsGoal() {
        let recovery = RecoveryCoordinator()
        let action = ActionIntent(type: "test", domain: .tool)
        let eval = CriticEvaluation(
            actionID: action.id, actionType: action.type,
            verdict: .failure, confidence: 0.9,
            preStateHash: "a", postStateHash: "a",
            stateChanged: false, detail: "fail"
        )
        _ = recovery.recover(action: action, evaluation: eval, goalID: "goal-5")
        XCTAssertNotNil(recovery.state(forGoal: "goal-5"))

        recovery.clearState(forGoal: "goal-5")
        XCTAssertNil(recovery.state(forGoal: "goal-5"))
    }
}

// MARK: - 22. Critic + Runtime Integration Test

final class CriticRuntimeIntegrationTests: XCTestCase {

    func testRuntimeHasCriticAndRecovery() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.critic)
        XCTAssertNotNil(runtime.recovery)
    }

    func testCriticEvaluatedEventEmitted() {
        let runtime = OracleRuntime()
        runtime.initialize()

        var criticEventReceived = false
        runtime.eventBus.subscribe { event in
            if case .criticEvaluated = event {
                criticEventReceived = true
            }
        }

        let goal = Goal(description: "read file test")
        runtime.process(goal: goal)
        XCTAssertTrue(criticEventReceived, "Runtime should emit criticEvaluated event")
    }

    func testExecutorResultIncludesStateHashes() {
        let executor = VerifiedActionExecutor()
        ActionRegistry.shared.registerDefaults()
        let action = ActionIntent(type: "log", domain: .system, parameters: ["message": "test"])
        let result = executor.execute(action: action)
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.preStateHash.isEmpty, "Result should include preStateHash")
        XCTAssertFalse(result.postStateHash.isEmpty, "Result should include postStateHash")
    }
}

// MARK: - 23. TraceReplayEngine Tests

final class TraceReplayEngineTests: XCTestCase {

    func testBeginAndEndTrace() {
        let engine = TraceReplayEngine()
        let id = engine.beginTrace(goalID: "g1", goalDescription: "test goal")
        XCTAssertFalse(id.isEmpty)

        let trace = engine.endTrace()
        XCTAssertNotNil(trace)
        XCTAssertEqual(trace?.goalID, "g1")
        XCTAssertEqual(trace?.steps.count, 0)
        XCTAssertNotNil(trace?.completedAt)
    }

    func testRecordSteps() {
        let engine = TraceReplayEngine()
        engine.beginTrace(goalID: "g2", goalDescription: "multi-step")

        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "pre1", postStateHash: "post1",
            verdict: .success, latencyMs: 5.0
        )
        engine.recordStep(
            actionType: "write_file", actionID: "a2",
            preStateHash: "pre2", postStateHash: "post2",
            verdict: .failure, latencyMs: 12.0
        )

        let trace = engine.endTrace()!
        XCTAssertEqual(trace.steps.count, 2)
        XCTAssertEqual(trace.successCount, 1)
        XCTAssertEqual(trace.failureCount, 1)
        XCTAssertEqual(trace.totalLatencyMs, 17.0, accuracy: 0.1)
    }

    func testCompareIdenticalTraces() {
        let engine = TraceReplayEngine()

        // Record trace A
        engine.beginTrace(goalID: "g3", goalDescription: "compare A")
        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "p1", postStateHash: "p2",
            verdict: .success, latencyMs: 1.0
        )
        let traceA = engine.endTrace()!

        // Record trace B (identical)
        engine.beginTrace(goalID: "g4", goalDescription: "compare B")
        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "p1", postStateHash: "p2",
            verdict: .success, latencyMs: 2.0
        )
        let traceB = engine.endTrace()!

        let divergences = TraceReplayEngine.compare(expected: traceA, actual: traceB)
        XCTAssertTrue(divergences.isEmpty, "Identical traces should have no divergences")
    }

    func testCompareDivergentTraces() {
        let engine = TraceReplayEngine()

        engine.beginTrace(goalID: "g5", goalDescription: "expected")
        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "p1", postStateHash: "p2",
            verdict: .success, latencyMs: 1.0
        )
        let expected = engine.endTrace()!

        engine.beginTrace(goalID: "g6", goalDescription: "actual")
        engine.recordStep(
            actionType: "write_file", actionID: "a1",
            preStateHash: "p1", postStateHash: "p3",
            verdict: .failure, latencyMs: 1.0
        )
        let actual = engine.endTrace()!

        let divergences = TraceReplayEngine.compare(expected: expected, actual: actual)
        XCTAssertFalse(divergences.isEmpty, "Different action types should produce divergence")
        XCTAssertTrue(divergences[0].reason.contains("action:"))
    }

    func testCompareDifferentLengthTraces() {
        let engine = TraceReplayEngine()

        engine.beginTrace(goalID: "g7", goalDescription: "short")
        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "p1", postStateHash: "p2",
            verdict: .success, latencyMs: 1.0
        )
        let shortTrace = engine.endTrace()!

        engine.beginTrace(goalID: "g8", goalDescription: "long")
        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "p1", postStateHash: "p2",
            verdict: .success, latencyMs: 1.0
        )
        engine.recordStep(
            actionType: "write_file", actionID: "a2",
            preStateHash: "p2", postStateHash: "p3",
            verdict: .success, latencyMs: 2.0
        )
        let longTrace = engine.endTrace()!

        let divergences = TraceReplayEngine.compare(expected: shortTrace, actual: longTrace)
        XCTAssertEqual(divergences.count, 1, "Extra step should produce one divergence")
        XCTAssertTrue(divergences[0].reason.contains("extra"))
    }

    func testRenderTrace() {
        let engine = TraceReplayEngine()
        engine.beginTrace(goalID: "g9", goalDescription: "render test")
        engine.recordStep(
            actionType: "log", actionID: "a1",
            preStateHash: "pre", postStateHash: "post",
            verdict: .success, latencyMs: 3.5
        )
        let trace = engine.endTrace()!
        let rendered = engine.renderTrace(trace)
        XCTAssertTrue(rendered.contains("Replay Trace"))
        XCTAssertTrue(rendered.contains("log"))
        XCTAssertTrue(rendered.contains("render test"))
    }

    func testRecentTraces() {
        let engine = TraceReplayEngine()
        for i in 0..<5 {
            engine.beginTrace(goalID: "g-\(i)", goalDescription: "trace \(i)")
            engine.recordStep(
                actionType: "log", actionID: "a-\(i)",
                preStateHash: "p", postStateHash: "p",
                verdict: .success, latencyMs: 1.0
            )
            _ = engine.endTrace()
        }
        let recent = engine.recentTraces(limit: 3)
        XCTAssertEqual(recent.count, 3)
    }
}

// MARK: - 24. StateMemoryIndex Tests

final class StateMemoryIndexTests: XCTestCase {

    func testRecordAndQuery() {
        let index = StateMemoryIndex()
        let sig = StateSignature(hash: "state-1")

        index.record(stateSignature: sig, actionType: "click", success: true)
        index.record(stateSignature: sig, actionType: "click", success: true)
        index.record(stateSignature: sig, actionType: "click", success: false)

        let stats = index.stats(for: sig)
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].attempts, 3)
        XCTAssertEqual(stats[0].successes, 2)
    }

    func testLikelyActions() {
        let index = StateMemoryIndex()
        let sig = StateSignature(hash: "state-2")

        // click: 4/5 = 80% success (above threshold)
        for _ in 0..<4 { index.record(stateSignature: sig, actionType: "click", success: true) }
        index.record(stateSignature: sig, actionType: "click", success: false)

        // type: 1/5 = 20% success (below threshold)
        for _ in 0..<4 { index.record(stateSignature: sig, actionType: "type", success: false) }
        index.record(stateSignature: sig, actionType: "type", success: true)

        let likely = index.likelyActions(for: sig)
        XCTAssertTrue(likely.contains("click"), "80% success should be likely")
        XCTAssertFalse(likely.contains("type"), "20% success should not be likely")
    }

    func testSuccessRate() {
        let index = StateMemoryIndex()
        let sig = StateSignature(hash: "state-3")

        index.record(stateSignature: sig, actionType: "read", success: true)
        index.record(stateSignature: sig, actionType: "read", success: true)
        index.record(stateSignature: sig, actionType: "read", success: false)

        let rate = index.successRate(for: sig, actionType: "read")
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate!, 2.0 / 3.0, accuracy: 0.01)
    }

    func testHasMemory() {
        let index = StateMemoryIndex()
        let sig = StateSignature(hash: "state-4")

        XCTAssertFalse(index.hasMemory(for: sig))
        index.record(stateSignature: sig, actionType: "log", success: true)
        XCTAssertTrue(index.hasMemory(for: sig))
    }

    func testStateSignatureFrom() {
        let sig1 = StateSignature.from(context: "hello", actionTypes: ["click"])
        let sig2 = StateSignature.from(context: "hello", actionTypes: ["click"])
        let sig3 = StateSignature.from(context: "world", actionTypes: ["click"])

        XCTAssertEqual(sig1.hash, sig2.hash, "Same inputs should produce same hash")
        XCTAssertNotEqual(sig1.hash, sig3.hash, "Different inputs should produce different hash")
    }

    func testReset() {
        let index = StateMemoryIndex()
        let sig = StateSignature(hash: "state-5")
        index.record(stateSignature: sig, actionType: "log", success: true)
        XCTAssertEqual(index.stateCount, 1)

        index.reset()
        XCTAssertEqual(index.stateCount, 0)
    }
}

// MARK: - 25. MetricsRecorder Tests

final class MetricsRecorderTests: XCTestCase {

    func testRecordGoals() {
        let metrics = MetricsRecorder()
        metrics.recordGoal(success: true, stepCount: 3)
        metrics.recordGoal(success: true, stepCount: 5)
        metrics.recordGoal(success: false, stepCount: 2)

        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalGoalsProcessed, 3)
        XCTAssertEqual(snap.taskSuccessRate, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(snap.averageStepsPerGoal, 10.0 / 3.0, accuracy: 0.01)
    }

    func testRecordActions() {
        let metrics = MetricsRecorder()
        metrics.recordAction(type: "click", success: true)
        metrics.recordAction(type: "click", success: true)
        metrics.recordAction(type: "click", success: false)
        metrics.recordAction(type: "type", success: true)

        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalActionsExecuted, 4)
        XCTAssertEqual(snap.actionSuccessRate, 3.0 / 4.0, accuracy: 0.01)
        XCTAssertEqual(metrics.successRate(forAction: "click"), 2.0 / 3.0, accuracy: 0.01)
    }

    func testRecordLatency() {
        let metrics = MetricsRecorder()
        metrics.recordLatency(10.0)
        metrics.recordLatency(20.0)
        metrics.recordLatency(30.0)

        let snap = metrics.snapshot()
        XCTAssertEqual(snap.averageLatencyMs, 20.0, accuracy: 0.01)
    }

    func testRecordRecovery() {
        let metrics = MetricsRecorder()
        metrics.recordRecovery()
        metrics.recordRecovery()

        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalRecoveryAttempts, 2)
    }

    func testAllActionStats() {
        let metrics = MetricsRecorder()
        metrics.recordAction(type: "click", success: true)
        metrics.recordAction(type: "type", success: false)

        let stats = metrics.allActionStats()
        XCTAssertEqual(stats.count, 2)
    }

    func testSummaryOutput() {
        let metrics = MetricsRecorder()
        metrics.recordGoal(success: true, stepCount: 3)
        metrics.recordAction(type: "log", success: true)
        let summary = metrics.summary()
        XCTAssertTrue(summary.contains("Goals:"))
        XCTAssertTrue(summary.contains("Actions:"))
    }

    func testReset() {
        let metrics = MetricsRecorder()
        metrics.recordGoal(success: true, stepCount: 1)
        metrics.recordAction(type: "log", success: true)
        metrics.recordRecovery()
        metrics.recordLatency(5.0)

        metrics.reset()
        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalGoalsProcessed, 0)
        XCTAssertEqual(snap.totalActionsExecuted, 0)
        XCTAssertEqual(snap.totalRecoveryAttempts, 0)
    }
}

// MARK: - 26. Dashboard + Metrics Integration Test

final class DashboardMetricsIntegrationTests: XCTestCase {

    func testDashboardSnapshotIncludesMetrics() {
        let recorder = TraceRecorder()
        let bus = EventBus()
        let dashboard = SystemDashboard(traceRecorder: recorder, eventBus: bus)
        let metrics = MetricsRecorder()
        let critic = CriticLoop()

        dashboard.attachMetrics(metrics)
        dashboard.attachCritic(critic)

        metrics.recordAction(type: "log", success: true)
        metrics.recordRecovery()
        metrics.recordLatency(5.0)

        let snap = dashboard.snapshot()
        XCTAssertEqual(snap.totalRecoveries, 1)
        XCTAssertEqual(snap.averageLatencyMs, 5.0, accuracy: 0.01)
        XCTAssertEqual(snap.criticSuccessRate, 1.0, accuracy: 0.01)
    }

    func testRuntimeIncludesReplayAndMetrics() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.replayEngine)
        XCTAssertNotNil(runtime.stateMemory)
        XCTAssertNotNil(runtime.metrics)
    }

    func testRuntimeProcessRecordsMetrics() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let goal = Goal(description: "read file test")
        runtime.process(goal: goal)

        let snap = runtime.metrics.snapshot()
        XCTAssertEqual(snap.totalGoalsProcessed, 1)
        XCTAssertGreaterThan(snap.totalActionsExecuted, 0, "Should have executed at least one action")
    }

    func testRuntimeProcessRecordsReplayTrace() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let goal = Goal(description: "read file replay")
        runtime.process(goal: goal)

        let traces = runtime.replayEngine.completedTraces()
        XCTAssertEqual(traces.count, 1, "Should have one completed replay trace")
        XCTAssertFalse(traces[0].steps.isEmpty, "Replay trace should contain steps")
    }
}
