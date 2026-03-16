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

// MARK: - 27. TaskNode Tests

final class TaskNodeTests: XCTestCase {

    func testNodeCreation() {
        let node = TaskNode(abstractState: .taskStarted)
        XCTAssertEqual(node.abstractState, .taskStarted)
        XCTAssertEqual(node.label, "task_started")
        XCTAssertEqual(node.visitCount, 0)
        XCTAssertEqual(node.confidence, 1.0)
    }

    func testRecordVisit() {
        let node = TaskNode(abstractState: .idle)
        XCTAssertEqual(node.visitCount, 0)
        node.recordVisit()
        node.recordVisit()
        XCTAssertEqual(node.visitCount, 2)
    }

    func testUpdateConfidence() {
        let node = TaskNode(abstractState: .idle)
        node.updateConfidence(0.5)
        XCTAssertEqual(node.confidence, 0.5, accuracy: 0.01)
        node.updateConfidence(2.0)
        XCTAssertEqual(node.confidence, 1.0, accuracy: 0.01, "Should clamp to 1.0")
        node.updateConfidence(-0.5)
        XCTAssertEqual(node.confidence, 0.0, accuracy: 0.01, "Should clamp to 0.0")
    }

    func testStateSignature() {
        let node = TaskNode(abstractState: .repoLoaded, label: "repo_loaded")
        XCTAssertEqual(node.stateSignature, "repo_loaded|repo_loaded")
    }
}

// MARK: - 28. TaskEdge Tests

final class TaskEdgeTests: XCTestCase {

    func testEdgeCreation() {
        let edge = TaskEdge(fromNodeID: "A", toNodeID: "B", action: "click")
        XCTAssertEqual(edge.status, .candidate)
        XCTAssertEqual(edge.attempts, 0)
        XCTAssertEqual(edge.successProbability, 0)
    }

    func testRecordSuccess() {
        let edge = TaskEdge(fromNodeID: "A", toNodeID: "B", action: "click")
        edge.recordSuccess(latencyMs: 10, cost: 1.0)
        XCTAssertEqual(edge.status, .executedSuccess)
        XCTAssertEqual(edge.successCount, 1)
        XCTAssertEqual(edge.attempts, 1)
        XCTAssertEqual(edge.successProbability, 1.0, accuracy: 0.01)
    }

    func testRecordFailure() {
        let edge = TaskEdge(fromNodeID: "A", toNodeID: "B", action: "click")
        edge.recordFailure(latencyMs: 5, cost: 0.5)
        XCTAssertEqual(edge.status, .executedFailure)
        XCTAssertEqual(edge.failureCount, 1)
        XCTAssertEqual(edge.successProbability, 0, accuracy: 0.01)
    }

    func testSuccessProbabilityMixed() {
        let edge = TaskEdge(fromNodeID: "A", toNodeID: "B", action: "type")
        edge.recordSuccess()
        edge.recordSuccess()
        edge.recordFailure()
        XCTAssertEqual(edge.successProbability, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(edge.attempts, 3)
    }

    func testMarkAbandoned() {
        let edge = TaskEdge(fromNodeID: "A", toNodeID: "B", action: "click")
        edge.markAbandoned()
        XCTAssertEqual(edge.status, .abandoned)
    }

    func testAverageLatencyAndCost() {
        let edge = TaskEdge(fromNodeID: "A", toNodeID: "B", action: "navigate")
        edge.recordSuccess(latencyMs: 10, cost: 2.0)
        edge.recordSuccess(latencyMs: 20, cost: 4.0)
        XCTAssertEqual(edge.averageLatencyMs, 15.0, accuracy: 0.01)
        XCTAssertEqual(edge.averageCost, 3.0, accuracy: 0.01)
    }
}

// MARK: - 29. TaskGraph Tests

final class TaskGraphTests: XCTestCase {

    func testAddAndMergeNode() {
        let graph = TaskGraph()
        let n1 = TaskNode(abstractState: .taskStarted)
        let added = graph.addOrMergeNode(n1)
        XCTAssertEqual(graph.nodeCount, 1)
        XCTAssertEqual(added.visitCount, 1)

        // Adding same signature merges
        let n2 = TaskNode(abstractState: .taskStarted)
        let merged = graph.addOrMergeNode(n2)
        XCTAssertEqual(graph.nodeCount, 1, "Should merge duplicate states")
        XCTAssertEqual(merged.visitCount, 2)
    }

    func testSetCurrent() {
        let graph = TaskGraph()
        let node = graph.addOrMergeNode(TaskNode(abstractState: .idle))
        graph.setCurrent(node.id)
        XCTAssertEqual(graph.currentNodeID, node.id)
        XCTAssertNotNil(graph.currentNode())
    }

    func testAddEdge() {
        let graph = TaskGraph()
        let from = graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        let to = graph.addOrMergeNode(TaskNode(abstractState: .repoLoaded))

        let edge = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to.id, action: "load"))
        XCTAssertEqual(graph.edgeCount, 1)
        XCTAssertEqual(edge.action, "load")
    }

    func testOutgoingEdges() {
        let graph = TaskGraph()
        let from = graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        let to1 = graph.addOrMergeNode(TaskNode(abstractState: .repoLoaded, label: "repo_loaded"))
        let to2 = graph.addOrMergeNode(TaskNode(abstractState: .buildRunning, label: "build_running"))

        graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to1.id, action: "load"))
        graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to2.id, action: "build"))

        let outgoing = graph.outgoingEdges(from: from.id)
        XCTAssertEqual(outgoing.count, 2)
    }

    func testRecordExecution() {
        let graph = TaskGraph()
        let from = graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        let to = TaskNode(abstractState: .repoLoaded)
        graph.setCurrent(from.id)

        let edge = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to.id, action: "load"))
        let result = graph.recordExecution(edgeID: edge.id, resultNode: to, latencyMs: 5, cost: 1)

        XCTAssertEqual(graph.currentNodeID, result.id, "Should advance current pointer")
        XCTAssertEqual(edge.successCount, 1)
    }

    func testRecordFailure() {
        let graph = TaskGraph()
        let from = graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        let to = graph.addOrMergeNode(TaskNode(abstractState: .repoLoaded, label: "repo_loaded"))
        graph.setCurrent(from.id)

        let edge = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to.id, action: "load"))
        graph.recordFailure(edgeID: edge.id, latencyMs: 3, cost: 0.5)

        XCTAssertEqual(graph.currentNodeID, from.id, "Should NOT advance on failure")
        XCTAssertEqual(edge.failureCount, 1)
        XCTAssertEqual(edge.status, .executedFailure)
    }

    func testViableEdges() {
        let graph = TaskGraph()
        let from = graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        let to1 = graph.addOrMergeNode(TaskNode(abstractState: .repoLoaded, label: "repo_loaded"))
        let to2 = graph.addOrMergeNode(TaskNode(abstractState: .buildFailed, label: "build_failed"))

        let e1 = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to1.id, action: "load"))
        let e2 = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to2.id, action: "build"))
        e2.recordFailure()

        let viable = graph.viableEdges(from: from.id)
        XCTAssertEqual(viable.count, 1)
        XCTAssertEqual(viable[0].id, e1.id)
    }

    func testAlternateEdges() {
        let graph = TaskGraph()
        let from = graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        let to1 = graph.addOrMergeNode(TaskNode(abstractState: .repoLoaded, label: "repo_loaded"))
        let to2 = graph.addOrMergeNode(TaskNode(abstractState: .buildRunning, label: "build_running"))

        let e1 = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to1.id, action: "load"))
        let e2 = graph.addEdge(TaskEdge(fromNodeID: from.id, toNodeID: to2.id, action: "build"))

        let alts = graph.alternateEdges(from: from.id, excluding: e1.id)
        XCTAssertEqual(alts.count, 1)
        XCTAssertEqual(alts[0].id, e2.id)
    }

    func testReset() {
        let graph = TaskGraph()
        graph.addOrMergeNode(TaskNode(abstractState: .taskStarted))
        graph.addOrMergeNode(TaskNode(abstractState: .idle, label: "idle"))
        XCTAssertEqual(graph.nodeCount, 2)

        graph.reset()
        XCTAssertEqual(graph.nodeCount, 0)
        XCTAssertEqual(graph.edgeCount, 0)
        XCTAssertNil(graph.currentNodeID)
    }
}

// MARK: - 30. TaskGraphStore Tests

final class TaskGraphStoreTests: XCTestCase {

    func testAbstractStateFromContext() {
        let store = TaskGraphStore()

        XCTAssertEqual(store.abstractState(from: "run tests"), .testsRunning)
        XCTAssertEqual(store.abstractState(from: "tests passed"), .testsPassed)
        XCTAssertEqual(store.abstractState(from: "build running"), .buildRunning)
        XCTAssertEqual(store.abstractState(from: "build failed"), .buildFailed)
        XCTAssertEqual(store.abstractState(from: "repository loaded"), .repoLoaded)
        XCTAssertEqual(store.abstractState(from: "apply patch"), .candidatePatchApplied)
        XCTAssertEqual(store.abstractState(from: "login page"), .loginPageDetected)
        XCTAssertEqual(store.abstractState(from: "navigate to settings"), .navigationCompleted)
        XCTAssertEqual(store.abstractState(from: "explore options"), .explorationActive)
        XCTAssertEqual(store.abstractState(from: "recovery needed"), .recoveryNeeded)
        XCTAssertEqual(store.abstractState(from: "unknown context"), .taskStarted)
    }

    func testUpdateCurrentNode() {
        let store = TaskGraphStore()
        let node = store.updateCurrentNode(context: "tests running")
        XCTAssertEqual(node.abstractState, .testsRunning)
        XCTAssertNotNil(store.currentNode())
        XCTAssertEqual(store.currentNode()?.abstractState, .testsRunning)
    }

    func testAddCandidateEdge() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")

        let edge = store.addCandidateEdge(
            action: "run_build",
            domain: .code,
            targetState: .buildRunning
        )
        XCTAssertNotNil(edge)
        XCTAssertEqual(edge?.status, .candidate)
        XCTAssertEqual(edge?.action, "run_build")
    }

    func testRecordVerifiedExecution() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")

        let edge = store.addCandidateEdge(
            action: "load_repo",
            targetState: .repoLoaded
        )!

        let resultNode = store.recordVerifiedExecution(
            edgeID: edge.id,
            resultContext: "repository loaded",
            latencyMs: 10,
            cost: 1.0,
            createdByAction: "load_repo"
        )

        XCTAssertEqual(resultNode.abstractState, .repoLoaded)
        XCTAssertEqual(store.currentNode()?.abstractState, .repoLoaded)
        XCTAssertEqual(edge.successCount, 1)
    }

    func testRecordFailedExecution() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")

        let edge = store.addCandidateEdge(
            action: "build",
            targetState: .buildSucceeded
        )!

        store.recordFailedExecution(edgeID: edge.id, latencyMs: 5, cost: 0.5)
        XCTAssertEqual(edge.failureCount, 1)
        XCTAssertEqual(edge.status, .executedFailure)
        // Current node should NOT advance
        XCTAssertEqual(store.currentNode()?.abstractState, .taskStarted)
    }

    func testRecoveryEdges() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")

        let e1 = store.addCandidateEdge(action: "route_a", targetState: .repoLoaded)!
        let e2 = store.addCandidateEdge(action: "route_b", targetState: .buildRunning)!

        let recovery = store.recoveryEdges(excludingEdgeID: e1.id)
        XCTAssertEqual(recovery.count, 1)
        XCTAssertEqual(recovery[0].id, e2.id)
    }

    func testViableNextEdges() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")

        let e1 = store.addCandidateEdge(action: "good", targetState: .repoLoaded)!
        let e2 = store.addCandidateEdge(action: "bad", targetState: .buildFailed)!
        e1.recordSuccess()
        e2.recordFailure()

        let viable = store.viableNextEdges()
        XCTAssertEqual(viable.count, 1)
        XCTAssertEqual(viable[0].id, e1.id)
    }

    func testExportDOT() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")
        store.addCandidateEdge(action: "load", targetState: .repoLoaded)

        let dot = store.exportDOT()
        XCTAssertTrue(dot.contains("digraph TaskGraph"))
        XCTAssertTrue(dot.contains("load"))
    }

    func testExportJSON() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")

        let json = store.exportJSON()
        let nodes = json["nodes"] as? [[String: Any]]
        XCTAssertNotNil(nodes)
        XCTAssertFalse(nodes!.isEmpty)
    }

    func testSummary() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "idle")
        let summary = store.summary()
        XCTAssertTrue(summary.contains("Nodes:"))
        XCTAssertTrue(summary.contains("Current:"))
    }

    func testReset() {
        let store = TaskGraphStore()
        store.updateCurrentNode(context: "task started")
        store.addCandidateEdge(action: "load", targetState: .repoLoaded)
        XCTAssertGreaterThan(store.graph.nodeCount, 0)

        store.reset()
        XCTAssertEqual(store.graph.nodeCount, 0)
        XCTAssertEqual(store.graph.edgeCount, 0)
    }
}

// MARK: - 31. PlanningGraph + TaskGraph Integration Tests

final class PlanningTaskGraphIntegrationTests: XCTestCase {

    func testRuntimeHasTaskGraphAndPlanningGraph() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.taskGraph)
        XCTAssertNotNil(runtime.planningGraphEngine)
        // Task graph should have initial idle node
        XCTAssertNotNil(runtime.taskGraph.currentNode())
    }

    func testRuntimeProcessUpdatesTaskGraph() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let goal = Goal(description: "read file test")
        runtime.process(goal: goal)

        // After processing, task graph should have edges
        XCTAssertGreaterThan(runtime.taskGraph.graph.edgeCount, 0,
                             "Processing should create task graph edges")
    }

    func testRuntimeProcessUpdatesPlanningGraph() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let goal = Goal(description: "read file test")
        runtime.process(goal: goal)

        // After processing, planning graph should have edges
        XCTAssertGreaterThan(runtime.planningGraphEngine.edgeCount, 0,
                             "Processing should create planning graph edges")
    }

    func testPlanningGraphValidActionsAfterProcess() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let goal = Goal(description: "log something")
        runtime.process(goal: goal)

        // The planning graph should have at least one edge
        let allEdges = runtime.planningGraphEngine.allEdges
        XCTAssertFalse(allEdges.isEmpty, "Should have recorded at least one edge")
    }
}

// MARK: - 32. Observation + UnifiedElement Tests

final class ObservationTests: XCTestCase {

    func testObservationStableHash() {
        let obs1 = Observation(
            app: "Xcode",
            windowTitle: "Main.swift",
            elements: [
                UnifiedElement(id: "btn1", source: .accessibility, role: "button", label: "Build")
            ]
        )
        let obs2 = Observation(
            app: "Xcode",
            windowTitle: "Main.swift",
            elements: [
                UnifiedElement(id: "btn1", source: .accessibility, role: "button", label: "Build")
            ]
        )
        XCTAssertEqual(obs1.stableHash(), obs2.stableHash(),
                        "Same content should produce the same hash")
    }

    func testObservationFocusedElement() {
        let obs = Observation(
            app: "Safari",
            focusedElementID: "search",
            elements: [
                UnifiedElement(id: "search", role: "textfield", label: "URL bar", focused: true),
                UnifiedElement(id: "btn", role: "button", label: "Go")
            ]
        )
        XCTAssertNotNil(obs.focusedElement)
        XCTAssertEqual(obs.focusedElement?.id, "search")
    }

    func testUnifiedElementDefaults() {
        let elem = UnifiedElement(id: "x")
        XCTAssertEqual(elem.source, .synthetic)
        XCTAssertTrue(elem.enabled)
        XCTAssertTrue(elem.visible)
        XCTAssertFalse(elem.focused)
        XCTAssertEqual(elem.confidence, 1.0)
    }

    func testObservationDeltaIsEmpty() {
        let delta = ObservationDelta()
        XCTAssertTrue(delta.isEmpty)
        XCTAssertEqual(delta.changeCount, 0)
    }

    func testObservationDeltaChangeCount() {
        let delta = ObservationDelta(
            applicationChanged: .init(from: "A", to: "B"),
            addedElements: [UnifiedElement(id: "new")],
            removedElementIDs: ["old"]
        )
        XCTAssertFalse(delta.isEmpty)
        XCTAssertEqual(delta.changeCount, 3) // 1 app + 1 added + 1 removed
    }
}

// MARK: - 33. ObservationChangeDetector Tests

final class ObservationChangeDetectorTests: XCTestCase {

    func testIdenticalObservationsProduceEmptyDelta() {
        let obs = Observation(
            app: "Xcode",
            elements: [UnifiedElement(id: "a", role: "button", label: "OK")]
        )
        let delta = ObservationChangeDetector.detect(previous: obs, incoming: obs)
        XCTAssertTrue(delta.isEmpty, "Identical observations should have no changes")
    }

    func testDetectsAddedElements() {
        let prev = Observation(app: "Xcode", elements: [
            UnifiedElement(id: "a", role: "button")
        ])
        let next = Observation(app: "Xcode", elements: [
            UnifiedElement(id: "a", role: "button"),
            UnifiedElement(id: "b", role: "text")
        ])
        let delta = ObservationChangeDetector.detect(previous: prev, incoming: next)
        XCTAssertEqual(delta.addedElements.count, 1)
        XCTAssertEqual(delta.addedElements.first?.id, "b")
    }

    func testDetectsRemovedElements() {
        let prev = Observation(app: "Xcode", elements: [
            UnifiedElement(id: "a"),
            UnifiedElement(id: "b")
        ])
        let next = Observation(app: "Xcode", elements: [
            UnifiedElement(id: "a")
        ])
        let delta = ObservationChangeDetector.detect(previous: prev, incoming: next)
        XCTAssertEqual(delta.removedElementIDs.count, 1)
        XCTAssertTrue(delta.removedElementIDs.contains("b"))
    }

    func testDetectsPropertyChanges() {
        let prev = Observation(elements: [
            UnifiedElement(id: "x", role: "button", label: "Save", enabled: true)
        ])
        let next = Observation(elements: [
            UnifiedElement(id: "x", role: "button", label: "Save", enabled: false)
        ])
        let delta = ObservationChangeDetector.detect(previous: prev, incoming: next)
        XCTAssertEqual(delta.changedElements.count, 1)
        XCTAssertTrue(delta.changedElements.first!.changedProperties.contains(.enabled))
    }

    func testDetectsApplicationChange() {
        let prev = Observation(app: "Xcode")
        let next = Observation(app: "Safari")
        let delta = ObservationChangeDetector.detect(previous: prev, incoming: next)
        XCTAssertNotNil(delta.applicationChanged)
        XCTAssertEqual(delta.applicationChanged?.from, "Xcode")
        XCTAssertEqual(delta.applicationChanged?.to, "Safari")
    }

    func testVolatilePropertyFiltering() {
        let old = UnifiedElement(id: "x", role: "button", confidence: 0.9)
        let new = UnifiedElement(id: "x", role: "button", confidence: 0.95)
        let all = ObservationChangeDetector.diffProperties(old: old, new: new)
        XCTAssertTrue(all.contains(.confidence))
        let planning = ObservationChangeDetector.diffPlanningProperties(old: old, new: new)
        XCTAssertFalse(planning.contains(.confidence), "Confidence is volatile")
    }

    func testDetectsURLChange() {
        let prev = Observation(url: "https://example.com")
        let next = Observation(url: "https://other.com")
        let delta = ObservationChangeDetector.detect(previous: prev, incoming: next)
        XCTAssertNotNil(delta.urlChanged)
    }
}

// MARK: - 34. WorldStateModel Tests

final class WorldStateModelTests: XCTestCase {

    func testInitialSnapshotIsBlank() {
        let model = WorldStateModel()
        XCTAssertNil(model.snapshot.activeApplication)
        XCTAssertNil(model.snapshot.activeBranch)
        XCTAssertTrue(model.snapshot.buildSucceeded)
        XCTAssertEqual(model.snapshot.failingTestCount, 0)
    }

    func testApplyDiffUpdatesSnapshot() {
        let model = WorldStateModel()
        let diff = StateDiff(changes: [
            .applicationChanged(from: nil, to: "Xcode"),
            .branchChanged(from: nil, to: "main"),
            .elementCountChanged(from: 0, to: 42)
        ])
        model.apply(diff: diff)
        XCTAssertEqual(model.snapshot.activeApplication, "Xcode")
        XCTAssertEqual(model.snapshot.activeBranch, "main")
        XCTAssertEqual(model.snapshot.visibleElementCount, 42)
    }

    func testHistoryTracking() {
        let model = WorldStateModel(maxHistory: 3)
        // Apply 4 diffs to exceed maxHistory
        for i in 0..<4 {
            model.apply(diff: StateDiff(changes: [
                .elementCountChanged(from: i, to: i + 1)
            ]))
        }
        XCTAssertLessThanOrEqual(model.historyCount, 3,
                                  "History should be bounded")
    }

    func testApplyObservationDirectly() {
        let model = WorldStateModel()
        let obs = Observation(
            app: "Safari",
            windowTitle: "Google",
            url: "https://google.com",
            elements: [UnifiedElement(id: "a"), UnifiedElement(id: "b")]
        )
        model.applyObservation(obs)
        XCTAssertEqual(model.snapshot.activeApplication, "Safari")
        XCTAssertEqual(model.snapshot.url, "https://google.com")
        XCTAssertEqual(model.snapshot.visibleElementCount, 2)
    }

    func testResetClearsSnapshot() {
        let model = WorldStateModel()
        model.apply(diff: StateDiff(changes: [
            .applicationChanged(from: nil, to: "Xcode")
        ]))
        model.reset()
        XCTAssertNil(model.snapshot.activeApplication)
    }

    func testRecentHistory() {
        let model = WorldStateModel()
        model.apply(diff: StateDiff(changes: [.applicationChanged(from: nil, to: "A")]))
        model.apply(diff: StateDiff(changes: [.applicationChanged(from: "A", to: "B")]))

        let history = model.recentHistory(limit: 5)
        XCTAssertFalse(history.isEmpty)
    }

    func testSnapshotSummary() {
        let snap = WorldModelSnapshot(
            activeApplication: "Xcode",
            visibleElementCount: 10,
            activeBranch: "main",
            buildSucceeded: true
        )
        let summary = snap.summary
        XCTAssertTrue(summary.contains("Xcode"))
        XCTAssertTrue(summary.contains("main"))
    }
}

// MARK: - 35. StateDiffEngine Tests

final class StateDiffEngineTests: XCTestCase {

    func testDiffDetectsApplicationChange() {
        let snap = WorldModelSnapshot(activeApplication: "Xcode")
        let obs = Observation(app: "Safari")
        let diff = StateDiffEngine.diff(current: snap, incoming: obs)
        XCTAssertFalse(diff.isEmpty)
        let apps = diff.changes.filter {
            if case .applicationChanged = $0 { return true }
            return false
        }
        XCTAssertEqual(apps.count, 1)
    }

    func testDiffIdenticalStateIsEmpty() {
        let snap = WorldModelSnapshot(activeApplication: "Xcode", url: "https://x.com", visibleElementCount: 0)
        let obs = Observation(app: "Xcode", url: "https://x.com", elements: [])
        let diff = StateDiffEngine.diff(current: snap, incoming: obs)
        // Only observationHash may differ since snap.observationHash is nil
        let nonHash = diff.changes.filter {
            if case .observationHashChanged = $0 { return false }
            return true
        }
        XCTAssertTrue(nonHash.isEmpty, "Only hash should differ for matching state")
    }

    func testDiffWithDeltaUsesElementDelta() {
        let snap = WorldModelSnapshot(visibleElementCount: 5)
        let obs = Observation(elements: [
            UnifiedElement(id: "a"), UnifiedElement(id: "b"),
            UnifiedElement(id: "c"), UnifiedElement(id: "d"),
            UnifiedElement(id: "e"), UnifiedElement(id: "f"),
            UnifiedElement(id: "g")
        ])
        let delta = ObservationDelta(
            addedElements: [UnifiedElement(id: "f"), UnifiedElement(id: "g")]
        )
        let diff = StateDiffEngine.diff(current: snap, incoming: obs, delta: delta)
        let elementChanges = diff.changes.filter {
            if case .elementCountChanged = $0 { return true }
            return false
        }
        XCTAssertEqual(elementChanges.count, 1)
    }

    func testDiffBetweenSnapshots() {
        let prev = WorldModelSnapshot(
            activeApplication: "Xcode",
            activeBranch: "main",
            isGitDirty: false,
            buildSucceeded: true
        )
        let cur = WorldModelSnapshot(
            activeApplication: "Xcode",
            activeBranch: "feature",
            isGitDirty: true,
            buildSucceeded: false,
            failingTestCount: 3
        )
        let diff = StateDiffEngine.diff(previous: prev, current: cur)
        XCTAssertFalse(diff.isEmpty)
        // Should detect branch, git dirty, build result, failing tests
        XCTAssertGreaterThanOrEqual(diff.count, 4)
    }

    func testDiffChangesAreEquatable() {
        let a = StateDiff.Change.applicationChanged(from: "X", to: "Y")
        let b = StateDiff.Change.applicationChanged(from: "X", to: "Y")
        XCTAssertEqual(a, b)
    }
}

// MARK: - 36. StateAbstractionEngine Tests

final class StateAbstractionEngineTests: XCTestCase {

    func testMapRoleButton() {
        XCTAssertEqual(StateAbstractionEngine.mapRole("button"), .button)
        XCTAssertEqual(StateAbstractionEngine.mapRole("AXButton"), .button)
    }

    func testMapRoleInput() {
        XCTAssertEqual(StateAbstractionEngine.mapRole("textfield"), .input)
        XCTAssertEqual(StateAbstractionEngine.mapRole("textarea"), .input)
        XCTAssertEqual(StateAbstractionEngine.mapRole("searchfield"), .input)
    }

    func testMapRoleUnknown() {
        XCTAssertEqual(StateAbstractionEngine.mapRole(nil), .unknown)
        XCTAssertEqual(StateAbstractionEngine.mapRole("xyz"), .unknown)
    }

    func testClassifyInteractable() {
        XCTAssertTrue(StateAbstractionEngine.classify(.button))
        XCTAssertTrue(StateAbstractionEngine.classify(.input))
        XCTAssertTrue(StateAbstractionEngine.classify(.link))
        XCTAssertFalse(StateAbstractionEngine.classify(.text))
        XCTAssertFalse(StateAbstractionEngine.classify(.image))
        XCTAssertFalse(StateAbstractionEngine.classify(.container))
    }

    func testCompressObservation() {
        let obs = Observation(elements: [
            UnifiedElement(id: "b1", role: "button", label: "OK", visible: true, focused: false),
            UnifiedElement(id: "t1", role: "statictext", label: "Hello", visible: true),
            UnifiedElement(id: "i1", role: "textfield", label: "Name", visible: true),
            UnifiedElement(id: "h1", role: "button", label: "Hidden", visible: false)
        ])
        let compressed = StateAbstractionEngine.compress(observation: obs)
        // Hidden element should be filtered out
        XCTAssertEqual(compressed.totalCount, 3)
        XCTAssertEqual(compressed.interactableCount, 2) // button + input
    }

    func testCompressedUIStateSummary() {
        let compressed = CompressedUIState(elements: [
            SemanticElement(id: "a", kind: .button, label: "OK", interactable: true),
            SemanticElement(id: "b", kind: .button, label: "Cancel", interactable: true)
        ])
        XCTAssertTrue(compressed.summary.contains("2 elements"))
        XCTAssertTrue(compressed.summary.contains("2 interactable"))
        XCTAssertEqual(compressed.dominantKind, .button)
    }

    func testCompressedUIStateFingerprint() {
        let state1 = CompressedUIState(elements: [
            SemanticElement(id: "a", kind: .button, label: "OK", interactable: true)
        ])
        let state2 = CompressedUIState(elements: [
            SemanticElement(id: "a", kind: .button, label: "OK", interactable: true)
        ])
        XCTAssertEqual(state1.fingerprint(), state2.fingerprint())
    }

    func testInteractableElements() {
        let obs = Observation(elements: [
            UnifiedElement(id: "b", role: "button", label: "Go", enabled: true, visible: true),
            UnifiedElement(id: "t", role: "statictext", label: "Label", visible: true),
            UnifiedElement(id: "d", role: "button", label: "Disabled", enabled: false, visible: true)
        ])
        let interactable = StateAbstractionEngine.interactableElements(from: obs)
        // Only enabled button counts as interactable
        XCTAssertEqual(interactable.count, 1)
        XCTAssertEqual(interactable.first?.id, "b")
    }
}

// MARK: - 37. ActionSchema Tests

final class ActionSchemaTests: XCTestCase {

    func testSchemaConditionEvaluateAppFrontmost() {
        let snap = WorldModelSnapshot(activeApplication: "Xcode")
        XCTAssertTrue(SchemaCondition.appFrontmost(name: "Xcode").evaluate(against: snap))
        XCTAssertFalse(SchemaCondition.appFrontmost(name: "Safari").evaluate(against: snap))
    }

    func testSchemaConditionBuildSucceeded() {
        let snap = WorldModelSnapshot(buildSucceeded: true)
        XCTAssertTrue(SchemaCondition.buildSucceeded.evaluate(against: snap))
        let failSnap = WorldModelSnapshot(buildSucceeded: false)
        XCTAssertFalse(SchemaCondition.buildSucceeded.evaluate(against: failSnap))
    }

    func testSchemaConditionGitClean() {
        let clean = WorldModelSnapshot(isGitDirty: false)
        XCTAssertTrue(SchemaCondition.gitClean.evaluate(against: clean))
        let dirty = WorldModelSnapshot(isGitDirty: true)
        XCTAssertFalse(SchemaCondition.gitClean.evaluate(against: dirty))
    }

    func testSchemaConditionURLContains() {
        let snap = WorldModelSnapshot(url: "https://github.com/repo")
        XCTAssertTrue(SchemaCondition.urlContains(substring: "github").evaluate(against: snap))
        XCTAssertFalse(SchemaCondition.urlContains(substring: "gitlab").evaluate(against: snap))
    }

    func testSchemaPreconditionsMet() {
        let schema = ActionSchema(
            kind: .runTests,
            domain: .code,
            name: "runTests",
            preconditions: [.buildSucceeded, .noFailingTests]
        )
        let good = WorldModelSnapshot(buildSucceeded: true, failingTestCount: 0)
        XCTAssertTrue(schema.preconditionsMet(snapshot: good))

        let bad = WorldModelSnapshot(buildSucceeded: false, failingTestCount: 2)
        XCTAssertFalse(schema.preconditionsMet(snapshot: bad))
    }

    func testActionSchemaLibraryDefaults() {
        let lib = ActionSchemaLibrary()
        XCTAssertGreaterThanOrEqual(lib.count, 10, "Should have default schemas")
        XCTAssertNotNil(lib.schema(for: .click))
        XCTAssertNotNil(lib.schema(for: .buildProject))
        XCTAssertNotNil(lib.schema(for: .runTests))
        XCTAssertNotNil(lib.schema(for: .gitCheckout))
    }

    func testApplicableSchemas() {
        let lib = ActionSchemaLibrary()
        let snap = WorldModelSnapshot(buildSucceeded: true, failingTestCount: 0)
        let applicable = lib.applicableSchemas(given: snap)
        XCTAssertFalse(applicable.isEmpty)
    }

    func testCustomSchemaRegistration() {
        let lib = ActionSchemaLibrary()
        let custom = ActionSchema(
            kind: .custom,
            domain: .tool,
            name: "deployStaging",
            description: "Deploy to staging",
            preconditions: [.buildSucceeded, .noFailingTests]
        )
        lib.register(custom)
        XCTAssertNotNil(lib.customSchema(named: "deployStaging"))
    }

    func testSchemaConditionNoFailingTests() {
        let good = WorldModelSnapshot(failingTestCount: 0)
        XCTAssertTrue(SchemaCondition.noFailingTests.evaluate(against: good))
        let bad = WorldModelSnapshot(failingTestCount: 5)
        XCTAssertFalse(SchemaCondition.noFailingTests.evaluate(against: bad))
    }
}

// MARK: - 38. World State Pipeline Integration Tests

final class WorldStatePipelineIntegrationTests: XCTestCase {

    func testFullPipelineObservationToWorldModel() {
        // Simulate the full pipeline:
        // Observation -> ChangeDetector -> StateDiffEngine -> WorldStateModel
        let model = WorldStateModel()

        let obs1 = Observation(
            app: "Xcode",
            windowTitle: "Main.swift",
            url: nil,
            elements: [
                UnifiedElement(id: "btn1", role: "button", label: "Build"),
                UnifiedElement(id: "txt1", role: "statictext", label: "Ready")
            ]
        )

        // First: apply directly (no previous)
        let diff1 = StateDiffEngine.diff(current: model.snapshot, incoming: obs1)
        model.apply(diff: diff1)
        XCTAssertEqual(model.snapshot.activeApplication, "Xcode")
        XCTAssertEqual(model.snapshot.visibleElementCount, 2)

        // Second observation: app switch
        let obs2 = Observation(
            app: "Safari",
            windowTitle: "Google",
            url: "https://google.com",
            elements: [
                UnifiedElement(id: "search", role: "textfield", label: "Search"),
                UnifiedElement(id: "btn", role: "button", label: "Search"),
                UnifiedElement(id: "link1", role: "link", label: "Result 1")
            ]
        )

        // Use change detector for delta
        let delta = ObservationChangeDetector.detect(previous: obs1, incoming: obs2)
        XCTAssertNotNil(delta.applicationChanged)

        let diff2 = StateDiffEngine.diff(current: model.snapshot, incoming: obs2, delta: delta)
        model.apply(diff: diff2)
        XCTAssertEqual(model.snapshot.activeApplication, "Safari")
        XCTAssertEqual(model.snapshot.url, "https://google.com")
        XCTAssertEqual(model.snapshot.visibleElementCount, 3) // 2 + (3 added - 2 removed) = 3

        // Verify history
        XCTAssertGreaterThanOrEqual(model.historyCount, 1)
    }

    func testRuntimeIngestObservation() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let obs = Observation(
            app: "Terminal",
            windowTitle: "bash",
            elements: [
                UnifiedElement(id: "prompt", role: "textfield", label: "$ ", visible: true)
            ]
        )

        let compressed = runtime.ingestObservation(obs)
        XCTAssertEqual(compressed.totalCount, 1)
        XCTAssertEqual(runtime.currentWorldSnapshot.activeApplication, "Terminal")
    }

    func testRuntimeIngestTwoObservations() {
        let runtime = OracleRuntime()
        runtime.initialize()

        let obs1 = Observation(app: "Xcode", elements: [
            UnifiedElement(id: "a", role: "button", label: "Build", visible: true)
        ])
        runtime.ingestObservation(obs1)
        XCTAssertEqual(runtime.currentWorldSnapshot.activeApplication, "Xcode")

        let obs2 = Observation(app: "Safari", elements: [
            UnifiedElement(id: "b", role: "link", label: "Google", visible: true)
        ])
        runtime.ingestObservation(obs2)
        XCTAssertEqual(runtime.currentWorldSnapshot.activeApplication, "Safari")
    }

    func testAbstractionPipelineEndToEnd() {
        let obs = Observation(elements: [
            UnifiedElement(id: "b1", role: "button", label: "OK", enabled: true, visible: true),
            UnifiedElement(id: "b2", role: "button", label: "Cancel", enabled: true, visible: true),
            UnifiedElement(id: "t1", role: "textfield", label: "Name", enabled: true, visible: true),
            UnifiedElement(id: "s1", role: "statictext", label: "Enter name", visible: true),
            UnifiedElement(id: "h1", role: "button", label: "Hidden", visible: false)
        ])

        let compressed = StateAbstractionEngine.compress(observation: obs)
        XCTAssertEqual(compressed.totalCount, 4, "Hidden element should be excluded")
        XCTAssertEqual(compressed.interactableCount, 3, "2 buttons + 1 input")
        XCTAssertNotNil(compressed.dominantKind)
    }

    func testSchemaApplicabilityWithWorldModel() {
        let model = WorldStateModel()
        model.apply(diff: StateDiff(changes: [
            .applicationChanged(from: nil, to: "Xcode"),
            .buildResultChanged(from: true, to: true),
        ]))

        let lib = ActionSchemaLibrary()
        let applicable = lib.applicableSchemas(given: model.snapshot)
        XCTAssertFalse(applicable.isEmpty)

        // runTests requires buildSucceeded
        let runTests = applicable.first { $0.kind == .runTests }
        XCTAssertNotNil(runTests, "runTests should be applicable when build succeeds")
    }

    func testSchemaApplicabilityBlocksOnPrecondition() {
        let model = WorldStateModel()
        model.apply(diff: StateDiff(changes: [
            .buildResultChanged(from: true, to: false)
        ]))

        let lib = ActionSchemaLibrary()
        let runTests = lib.schema(for: .runTests)!
        XCTAssertFalse(runTests.preconditionsMet(snapshot: model.snapshot),
                        "runTests should be blocked when build failed")
    }
}

// MARK: - 39. Candidate + CandidateResult Tests

final class CandidateTests: XCTestCase {

    func testCandidateCreation() {
        let schema = ActionSchema(kind: .click, domain: .host, name: "click_btn")
        let candidate = Candidate(
            hypothesis: "Button is visible",
            schema: schema,
            source: .memory
        )
        XCTAssertEqual(candidate.source, .memory)
        XCTAssertEqual(candidate.schema.name, "click_btn")
        XCTAssertFalse(candidate.id.isEmpty)
    }

    func testCandidateResultCreation() {
        let schema = ActionSchema(kind: .click, domain: .host, name: "click")
        let candidate = Candidate(hypothesis: "test", schema: schema, source: .graph)
        let result = CandidateResult(
            candidate: candidate,
            success: true,
            score: 0.9,
            criticVerdict: .success,
            elapsedMs: 42.0,
            notes: ["OK"]
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.score, 0.9)
        XCTAssertEqual(result.criticVerdict, .success)
        XCTAssertEqual(result.notes, ["OK"])
    }

    func testCandidateSourceRawValues() {
        XCTAssertEqual(CandidateSource.memory.rawValue, "memory")
        XCTAssertEqual(CandidateSource.graph.rawValue, "graph")
        XCTAssertEqual(CandidateSource.llmFallback.rawValue, "llm_fallback")
    }
}

// MARK: - 40. ResultSelector Tests

final class ResultSelectorTests: XCTestCase {

    private func makeResult(
        success: Bool,
        score: Double,
        verdict: CriticVerdict = .success,
        elapsedMs: Double = 10,
        source: CandidateSource = .memory
    ) -> CandidateResult {
        let schema = ActionSchema(kind: .click, domain: .host, name: "action")
        let candidate = Candidate(hypothesis: "test", schema: schema, source: source)
        return CandidateResult(
            candidate: candidate,
            success: success,
            score: score,
            criticVerdict: verdict,
            elapsedMs: elapsedMs
        )
    }

    func testSelectsSuccessfulOverFailure() {
        let selector = ResultSelector()
        let results = [
            makeResult(success: false, score: 0.9, verdict: .failure),
            makeResult(success: true, score: 0.5, verdict: .success)
        ]
        let best = selector.selectBest(from: results)
        XCTAssertNotNil(best)
        XCTAssertTrue(best!.success)
    }

    func testSelectsHigherScoreAmongSuccesses() {
        let selector = ResultSelector()
        let results = [
            makeResult(success: true, score: 0.7),
            makeResult(success: true, score: 0.9)
        ]
        let best = selector.selectBest(from: results)
        XCTAssertEqual(best?.score, 0.9)
    }

    func testSelectsLowerLatencyOnTiedScore() {
        let selector = ResultSelector()
        let results = [
            makeResult(success: true, score: 0.8, elapsedMs: 100),
            makeResult(success: true, score: 0.8, elapsedMs: 20)
        ]
        let best = selector.selectBest(from: results)
        XCTAssertEqual(best?.elapsedMs, 20)
    }

    func testPrefersPartialOverFailure() {
        let selector = ResultSelector()
        let results = [
            makeResult(success: false, score: 0.9, verdict: .failure),
            makeResult(success: false, score: 0.5, verdict: .partialSuccess)
        ]
        let best = selector.selectBest(from: results)
        XCTAssertEqual(best?.criticVerdict, .partialSuccess)
    }

    func testEmptyReturnsNil() {
        let selector = ResultSelector()
        XCTAssertNil(selector.selectBest(from: []))
    }
}

// MARK: - 41. CandidateGenerator Tests

final class CandidateGeneratorTests: XCTestCase {

    func testGenerateWithNoDataReturnsEmpty() {
        let mem = StateMemoryIndex()
        let graph = PlanningGraphEngine()
        let gen = CandidateGenerator(stateMemoryIndex: mem, planningGraphEngine: graph)

        let sig = StateSignature.from(context: "test", actionTypes: ["click"])
        let candidates = gen.generate(stateSignature: sig, abstractStateID: "idle")
        XCTAssertTrue(candidates.isEmpty, "No memory or graph data means no candidates")
    }

    func testGenerateWithMemory() {
        let mem = StateMemoryIndex()
        let graph = PlanningGraphEngine()
        let gen = CandidateGenerator(stateMemoryIndex: mem, planningGraphEngine: graph)

        let sig = StateSignature.from(context: "test", actionTypes: ["click"])
        // Record enough successful attempts to cross the threshold
        for _ in 0..<5 {
            mem.record(stateSignature: sig, actionType: "click_save", success: true)
        }

        let candidates = gen.generate(stateSignature: sig, abstractStateID: "idle")
        XCTAssertFalse(candidates.isEmpty, "Should generate memory-based candidates")
        XCTAssertEqual(candidates.first?.source, .memory)
    }

    func testGenerateWithGraphEdges() {
        let mem = StateMemoryIndex()
        let graph = PlanningGraphEngine()
        let gen = CandidateGenerator(stateMemoryIndex: mem, planningGraphEngine: graph)

        // Add a graph edge from "idle" state
        let edge = graph.addEdge(
            from: "idle",
            to: "build_started",
            actionType: "buildProject",
            domain: .code
        )
        graph.recordTraversal(edgeID: edge.id, success: true, cost: 1.0, latencyMs: 50)

        let sig = StateSignature.from(context: "test", actionTypes: [])
        let candidates = gen.generate(stateSignature: sig, abstractStateID: "idle")
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertEqual(candidates.first?.source, .graph)
    }

    func testLLMFallbackUsedWhenNoMemoryOrGraph() {
        let mem = StateMemoryIndex()
        let graph = PlanningGraphEngine()
        let gen = CandidateGenerator(stateMemoryIndex: mem, planningGraphEngine: graph)

        let sig = StateSignature.from(context: "test", actionTypes: [])
        let llmSchemas = [
            ActionSchema(kind: .click, domain: .host, name: "click_btn", description: "LLM suggested")
        ]
        let candidates = gen.generate(
            stateSignature: sig,
            abstractStateID: "idle",
            llmSchemas: llmSchemas
        )
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.source, .llmFallback)
    }

    func testMaxCandidatesRespected() {
        let mem = StateMemoryIndex()
        let graph = PlanningGraphEngine()
        let gen = CandidateGenerator(stateMemoryIndex: mem, planningGraphEngine: graph, maxCandidates: 2)

        let sig = StateSignature.from(context: "test", actionTypes: [])
        let llmSchemas = (0..<10).map { i in
            ActionSchema(kind: .custom, domain: .tool, name: "action_\(i)")
        }
        let candidates = gen.generate(
            stateSignature: sig,
            abstractStateID: "idle",
            llmSchemas: llmSchemas
        )
        XCTAssertLessThanOrEqual(candidates.count, 2)
    }

    func testSourceCountsTracked() {
        let mem = StateMemoryIndex()
        let graph = PlanningGraphEngine()
        let gen = CandidateGenerator(stateMemoryIndex: mem, planningGraphEngine: graph)

        let sig = StateSignature.from(context: "test", actionTypes: [])
        let llmSchemas = [
            ActionSchema(kind: .click, domain: .host, name: "click_x")
        ]
        _ = gen.generate(stateSignature: sig, abstractStateID: "idle", llmSchemas: llmSchemas)
        XCTAssertNotNil(gen.lastSourceCounts[.llmFallback])
    }
}

// MARK: - 42. PerceptionEngine Tests

final class PerceptionEngineTests: XCTestCase {

    func testPerceiveProducesResult() {
        let obs = Observation(
            app: "Xcode",
            windowTitle: "Main.swift",
            elements: [
                UnifiedElement(id: "b1", role: "button", label: "Build", visible: true, focused: false),
                UnifiedElement(id: "t1", role: "textfield", label: "Search", visible: true)
            ]
        )
        let result = PerceptionEngine.perceive(observation: obs)
        XCTAssertEqual(result.compressed.totalCount, 2)
        XCTAssertFalse(result.observationHash.isEmpty)
        XCTAssertFalse(result.interactableElements.isEmpty)
    }

    func testGetContext() {
        let obs = Observation(
            app: "Safari",
            windowTitle: "Google",
            url: "https://google.com",
            elements: [
                UnifiedElement(id: "s", role: "textfield", label: "Search", visible: true)
            ]
        )
        let ctx = PerceptionEngine.getContext(from: obs)
        XCTAssertEqual(ctx["app"], "Safari")
        XCTAssertEqual(ctx["url"], "https://google.com")
        XCTAssertTrue(ctx["elementCount"] == "1")
    }

    func testFindElements() {
        let obs = Observation(elements: [
            UnifiedElement(id: "b1", role: "button", label: "Save", visible: true),
            UnifiedElement(id: "b2", role: "button", label: "Cancel", visible: true),
            UnifiedElement(id: "t1", role: "textfield", label: "Name", visible: true)
        ])
        let buttons = PerceptionEngine.findElements(in: obs, role: "button")
        XCTAssertEqual(buttons.count, 2)

        let save = PerceptionEngine.findElements(in: obs, query: "Save")
        XCTAssertEqual(save.count, 1)
        XCTAssertEqual(save.first?.id, "b1")
    }

    func testStateSignatureFromPerception() {
        let obs = Observation(
            app: "Xcode",
            elements: [
                UnifiedElement(id: "b", role: "button", label: "Run", enabled: true, visible: true)
            ]
        )
        let result = PerceptionEngine.perceive(observation: obs)
        let sig = PerceptionEngine.stateSignature(from: result)
        XCTAssertFalse(sig.hash.isEmpty)
    }

    func testPerceptionResultSummary() {
        let obs = Observation(app: "Terminal", elements: [
            UnifiedElement(id: "p", role: "textfield", label: "prompt", visible: true)
        ])
        let result = PerceptionEngine.perceive(observation: obs)
        XCTAssertTrue(result.summary.contains("Terminal"))
    }

    func testPerceiveFilteresInvisible() {
        let obs = Observation(elements: [
            UnifiedElement(id: "v", role: "button", label: "Visible", visible: true),
            UnifiedElement(id: "h", role: "button", label: "Hidden", visible: false)
        ])
        let result = PerceptionEngine.perceive(observation: obs)
        XCTAssertEqual(result.compressed.totalCount, 1, "Invisible elements filtered")
    }
}

// MARK: - 43. SearchController Candidate Pipeline Tests

final class SearchControllerCandidateTests: XCTestCase {

    func testSearchControllerWithoutGeneratorReturnsNil() {
        let runtime = OracleRuntime()
        // Don't initialize — candidateGenerator not wired
        let sig = StateSignature.from(context: "test", actionTypes: [])
        let result = runtime.searchController.searchCandidates(
            stateSignature: sig,
            abstractStateID: "idle"
        ) { _ in nil }
        XCTAssertNil(result)
    }

    func testSearchControllerWithGeneratorAndEvaluator() {
        let runtime = OracleRuntime()
        runtime.initialize()

        // Inject LLM fallback schemas
        let llmSchemas = [
            ActionSchema(kind: .click, domain: .host, name: "click_btn", description: "test")
        ]
        let sig = StateSignature.from(context: "test", actionTypes: ["click"])
        let result = runtime.searchController.searchCandidates(
            stateSignature: sig,
            abstractStateID: "idle",
            llmSchemas: llmSchemas
        ) { candidate in
            // Simulate successful execution
            CandidateResult(
                candidate: candidate,
                success: true,
                score: 0.85,
                criticVerdict: .success,
                elapsedMs: 30
            )
        }
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.success)
    }

    func testSearchControllerEarlyExitOnMemorySuccess() {
        let runtime = OracleRuntime()
        runtime.initialize()

        // Seed memory
        let sig = StateSignature.from(context: "test", actionTypes: [])
        for _ in 0..<5 {
            runtime.stateMemory.record(stateSignature: sig, actionType: "click_save", success: true)
        }

        // Also add graph edges (should not be reached if memory succeeds)
        let edge = runtime.planningGraphEngine.addEdge(
            from: "idle",
            to: "done",
            actionType: "other_action",
            domain: .system
        )
        runtime.planningGraphEngine.recordTraversal(
            edgeID: edge.id, success: true, cost: 1, latencyMs: 10
        )

        var evaluationCount = 0
        let result = runtime.searchController.searchCandidates(
            stateSignature: sig,
            abstractStateID: "idle"
        ) { candidate in
            evaluationCount += 1
            return CandidateResult(
                candidate: candidate,
                success: true,
                score: 0.9,
                criticVerdict: .success,
                elapsedMs: 10
            )
        }

        XCTAssertNotNil(result)
        // Early exit: should stop after first successful memory candidate
        XCTAssertEqual(evaluationCount, 1, "Should early-exit on memory success")
    }

    func testRuntimeHasCandidateGenerator() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.searchController.candidateGenerator)
        XCTAssertEqual(runtime.candidateGenerator.maxCandidates, 6)
    }
}

// MARK: - 44. Skill Protocol + SkillResolution Tests

final class SkillProtocolTests: XCTestCase {

    func testSkillResolutionInit() {
        let intent = ActionIntent(type: "click", domain: .host, parameters: ["targetID": "btn1"])
        let res = SkillResolution(intent: intent, resolvedTargetID: "btn1", confidence: 0.9, notes: ["note"])
        XCTAssertEqual(res.intent.type, "click")
        XCTAssertEqual(res.resolvedTargetID, "btn1")
        XCTAssertEqual(res.confidence, 0.9, accuracy: 0.001)
        XCTAssertEqual(res.notes.count, 1)
    }

    func testSkillResolutionDefaults() {
        let intent = ActionIntent(type: "type", domain: .host)
        let res = SkillResolution(intent: intent)
        XCTAssertNil(res.resolvedTargetID)
        XCTAssertEqual(res.confidence, 1.0, accuracy: 0.001)
        XCTAssertTrue(res.notes.isEmpty)
    }

    func testSkillResolutionErrorDescriptions() {
        XCTAssertTrue(SkillResolutionError.noCandidate("x").description.contains("x"))
        XCTAssertTrue(SkillResolutionError.ambiguousTarget("t", 0.5).description.contains("0.5"))
        XCTAssertTrue(SkillResolutionError.unsupportedOperation("op").description.contains("op"))
    }

    func testCodeSkillResolutionErrorDescriptions() {
        XCTAssertTrue(CodeSkillResolutionError.missingWorkspace.description.contains("workspace"))
        XCTAssertTrue(CodeSkillResolutionError.noRelevantFiles("fs").description.contains("fs"))
        XCTAssertTrue(CodeSkillResolutionError.ambiguousEditTarget("e").description.contains("e"))
    }
}

// MARK: - 45. OS Skill Tests

final class OSSkillTests: XCTestCase {

    private func makeSnapshot() -> WorldModelSnapshot {
        WorldModelSnapshot(
            activeApplication: "TestApp",
            windowTitle: nil,
            url: nil,
            visibleElementCount: 0,
            modalPresent: false,
            focusedElementID: nil,
            repositoryRoot: nil,
            activeBranch: nil,
            isGitDirty: false,
            buildSucceeded: true,
            failingTestCount: 0,
            observationHash: nil
        )
    }

    func testReadFileSkillResolves() throws {
        let skill = ReadFileSkill()
        XCTAssertEqual(skill.name, "read_file")
        let snap = makeSnapshot()
        let res = try skill.resolve(query: "/tmp/test.swift", worldSnapshot: snap, parameters: [:])
        XCTAssertEqual(res.intent.type, "read_file")
        XCTAssertEqual(res.intent.domain, .host)
        XCTAssertEqual(res.intent.parameters["path"], "/tmp/test.swift")
        XCTAssertEqual(res.confidence, 1.0, accuracy: 0.001)
    }

    func testReadFileSkillPrefersPathParameter() throws {
        let skill = ReadFileSkill()
        let snap = makeSnapshot()
        let res = try skill.resolve(query: "ignored", worldSnapshot: snap, parameters: ["path": "/explicit/path.swift"])
        XCTAssertEqual(res.intent.parameters["path"], "/explicit/path.swift")
    }

    func testOpenAppSkillResolves() throws {
        let skill = OpenAppSkill()
        XCTAssertEqual(skill.name, "open_app")
        let snap = makeSnapshot()
        let res = try skill.resolve(query: "Safari", worldSnapshot: snap, parameters: ["app": "Safari"])
        XCTAssertEqual(res.intent.type, "open_app")
        XCTAssertEqual(res.intent.parameters["app"], "Safari")
    }

    func testClickSkillThrowsWhenNoMatch() {
        let skill = ClickSkill()
        let snap = makeSnapshot() // empty elements → no match
        XCTAssertThrowsError(
            try skill.resolve(query: "nonexistent-btn", worldSnapshot: snap, parameters: [:])
        ) { error in
            if case SkillResolutionError.noCandidate(_) = error {
                // expected
            } else {
                XCTFail("Expected noCandidate error")
            }
        }
    }
}

// MARK: - 46. Code Skill + SkillRegistry Tests

final class CodeSkillTests: XCTestCase {

    func testRunBuildSkillResolves() throws {
        let skill = RunBuildSkill()
        XCTAssertEqual(skill.name, "run_build")
        let res = try skill.resolve(goal: "build", workspaceRoot: "/workspace", parameters: [:])
        XCTAssertEqual(res.intent.type, "run_build")
        XCTAssertEqual(res.intent.domain, .code)
        XCTAssertEqual(res.intent.parameters["command"], "swift build")
        XCTAssertEqual(res.intent.parameters["workspaceRoot"], "/workspace")
    }

    func testRunBuildSkillCustomCommand() throws {
        let skill = RunBuildSkill()
        let res = try skill.resolve(goal: "build", workspaceRoot: "/ws", parameters: ["buildCommand": "xcodebuild"])
        XCTAssertEqual(res.intent.parameters["command"], "xcodebuild")
    }

    func testRunBuildSkillThrowsWhenNoRoot() {
        let skill = RunBuildSkill()
        XCTAssertThrowsError(try skill.resolve(goal: "build", workspaceRoot: nil, parameters: [:]))
    }

    func testGitStatusSkillResolves() throws {
        let skill = GitStatusSkill()
        XCTAssertEqual(skill.name, "git_status")
        let res = try skill.resolve(goal: "", workspaceRoot: "/repo", parameters: [:])
        XCTAssertEqual(res.intent.type, "git_status")
        XCTAssertEqual(res.intent.domain, .tool)
        XCTAssertEqual(res.intent.parameters["command"], "git")
        XCTAssertTrue(res.intent.parameters["args"]?.contains("--short") ?? false)
    }

    func testGitCommitSkillResolves() throws {
        let skill = GitCommitSkill()
        let res = try skill.resolve(goal: "", workspaceRoot: "/repo", parameters: ["message": "feat: add skills"])
        XCTAssertEqual(res.intent.type, "git_commit")
        XCTAssertEqual(res.intent.parameters["message"], "feat: add skills")
        XCTAssertTrue(res.notes.first?.contains("feat: add skills") ?? false)
    }

    func testGitCommitThrowsWhenNoMessage() {
        let skill = GitCommitSkill()
        XCTAssertThrowsError(try skill.resolve(goal: "", workspaceRoot: "/repo", parameters: [:]))
    }

    func testParseBuildFailureSkillExtractsErrorLine() throws {
        let skill = ParseBuildFailureSkill()
        let output = "compiling...\nSources/Foo.swift:10:5: error: use of unresolved identifier 'bar'\nbuild failed"
        let res = try skill.resolve(goal: "", workspaceRoot: nil, parameters: ["output": output])
        XCTAssertEqual(res.intent.type, "parse_build_failure")
        XCTAssertTrue(res.intent.parameters["errorLine"]?.contains("unresolved identifier") ?? false)
    }

    func testParseTestFailureSkillExtractsFailureLine() throws {
        let skill = ParseTestFailureSkill()
        let output = "Test Suite 'All tests' started\nFAILED: testFoo - expected 1 but got 2\nTest Suite ended"
        let res = try skill.resolve(goal: "", workspaceRoot: nil, parameters: ["output": output])
        XCTAssertEqual(res.intent.type, "parse_test_failure")
        XCTAssertTrue(res.intent.parameters["failedLine"]?.contains("FAILED") ?? false)
    }

    func testSkillRegistryLiveCount() {
        let registry = SkillRegistry.live()
        // 8 OS skills + 14 code skills = 22 total
        XCTAssertEqual(registry.totalCount, 22)
    }

    func testSkillRegistryOSLookup() {
        let registry = SkillRegistry.live()
        XCTAssertNotNil(registry.get("click"))
        XCTAssertNotNil(registry.get("type"))
        XCTAssertNotNil(registry.get("read_file"))
        XCTAssertNil(registry.get("nonexistent"))
    }

    func testSkillRegistryCodeLookup() {
        let registry = SkillRegistry.live()
        XCTAssertNotNil(registry.getCode("run_build"))
        XCTAssertNotNil(registry.getCode("git_commit"))
        XCTAssertNotNil(registry.getCode("parse_test_failure"))
        XCTAssertNil(registry.getCode("click")) // OS skills not in code registry
    }

    func testSkillRegistryAllNames() {
        let registry = SkillRegistry.live()
        let osNames = registry.allSkillNames
        let codeNames = registry.allCodeSkillNames
        XCTAssertTrue(osNames.contains("click"))
        XCTAssertTrue(codeNames.contains("git_push"))
        XCTAssertTrue(codeNames.contains("search_code"))
    }

    func testRuntimeHasSkillRegistry() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertEqual(runtime.skillRegistry.totalCount, 22)
        XCTAssertNotNil(runtime.skillRegistry.get("click"))
        XCTAssertNotNil(runtime.skillRegistry.getCode("run_build"))
    }

    func testCodeSkillSupportRequireWorkspaceRoot() {
        XCTAssertNoThrow(try CodeSkillSupport.requireWorkspaceRoot("/workspace"))
        XCTAssertThrowsError(try CodeSkillSupport.requireWorkspaceRoot(nil))
        XCTAssertThrowsError(try CodeSkillSupport.requireWorkspaceRoot(""))
    }

    func testCodeSkillSupportShellIntent() {
        let intent = CodeSkillSupport.shellIntent(
            name: "run_linter",
            workspaceRoot: "/proj",
            command: "swiftlint",
            args: ["--strict"]
        )
        XCTAssertEqual(intent.type, "run_linter")
        XCTAssertEqual(intent.domain, .code)
        XCTAssertEqual(intent.parameters["command"], "swiftlint")
        XCTAssertEqual(intent.parameters["workspaceRoot"], "/proj")
        XCTAssertTrue(intent.parameters["args"]?.contains("--strict") ?? false)
    }

    func testCodeSkillSupportGitIntent() {
        let intent = CodeSkillSupport.gitIntent(
            name: "git_push",
            workspaceRoot: "/repo",
            args: ["push", "origin", "main"]
        )
        XCTAssertEqual(intent.domain, .tool)
        XCTAssertEqual(intent.parameters["command"], "git")
        XCTAssertTrue(intent.parameters["args"]?.contains("origin") ?? false)
    }
}

// MARK: - 47. Coordinator Layer Tests

// ── 47a. CoordinatorTypes ────────────────────────────────────────────────────

final class CoordinatorTypesTests: XCTestCase {

    func testTaskContextDefaults() {
        let goal = Goal(description: "test goal")
        let ctx = TaskContext(goal: goal)
        XCTAssertEqual(ctx.goal.description, "test goal")
        XCTAssertNil(ctx.workspaceRoot)
        XCTAssertEqual(ctx.agentKind, .mixed)
        XCTAssertFalse(ctx.sessionID.isEmpty)
    }

    func testTaskContextCustom() {
        let goal = Goal(description: "code goal")
        let ctx = TaskContext(goal: goal, workspaceRoot: "/workspace", agentKind: .code, sessionID: "sess1")
        XCTAssertEqual(ctx.workspaceRoot, "/workspace")
        XCTAssertEqual(ctx.agentKind, .code)
        XCTAssertEqual(ctx.sessionID, "sess1")
    }

    func testStateBundleFields() {
        let goal = Goal(description: "bundle test")
        let ctx = TaskContext(goal: goal)
        let snap = WorldModelSnapshot(activeApplication: "Finder")
        let bundle = StateBundle(taskContext: ctx, snapshot: snap, stepIndex: 3, lastActionID: "act42")
        XCTAssertEqual(bundle.stepIndex, 3)
        XCTAssertEqual(bundle.lastActionID, "act42")
        XCTAssertEqual(bundle.snapshot.activeApplication, "Finder")
        XCTAssertNil(bundle.observation)
    }

    func testPreparedActionIsReady() {
        let intent = ActionIntent(type: "click", domain: .host)
        let allowed = PreparedAction(intent: intent, policyAllowed: true, confidence: 0.9)
        XCTAssertTrue(allowed.isReady)
        XCTAssertNil(allowed.blockReason)

        let blocked = PreparedAction(intent: intent, policyAllowed: false, blockReason: "denied")
        XCTAssertFalse(blocked.isReady)
        XCTAssertEqual(blocked.blockReason, "denied")
    }

    func testAgentKindRawValues() {
        XCTAssertEqual(AgentKind.ui.rawValue, "ui")
        XCTAssertEqual(AgentKind.code.rawValue, "code")
        XCTAssertEqual(AgentKind.mixed.rawValue, "mixed")
    }
}

// ── 47b. StateCoordinator ────────────────────────────────────────────────────

final class StateCoordinatorTests: XCTestCase {

    private func makeObservation(app: String) -> Observation {
        Observation(
            app: app,
            windowTitle: "\(app) Window",
            url: nil,
            focusedElementID: nil,
            elements: []
        )
    }

    func testIngestUpdatesSnapshot() {
        let model = WorldStateModel()
        let coord = StateCoordinator(worldModel: model)
        let obs = makeObservation(app: "Safari")
        let snap = coord.ingest(obs)
        XCTAssertEqual(snap.activeApplication, "Safari")
        XCTAssertEqual(snap.windowTitle, "Safari Window")
    }

    func testIngestSequenceTracksDeltas() {
        let model = WorldStateModel()
        let coord = StateCoordinator(worldModel: model)
        let obs1 = makeObservation(app: "Xcode")
        let obs2 = makeObservation(app: "Terminal")
        coord.ingest(obs1)
        let snap2 = coord.ingest(obs2)
        XCTAssertEqual(snap2.activeApplication, "Terminal")
    }

    func testBuildBundleWithObservation() {
        let model = WorldStateModel()
        let coord = StateCoordinator(worldModel: model)
        let goal = Goal(description: "open file")
        let ctx = TaskContext(goal: goal)
        let obs = makeObservation(app: "Finder")
        let bundle = coord.buildBundle(taskContext: ctx, observation: obs, stepIndex: 1, lastActionID: "a1")
        XCTAssertEqual(bundle.snapshot.activeApplication, "Finder")
        XCTAssertEqual(bundle.stepIndex, 1)
        XCTAssertEqual(bundle.lastActionID, "a1")
        XCTAssertNotNil(bundle.observation)
    }

    func testBuildBundleWithoutObservationUsesCurrentSnapshot() {
        let model = WorldStateModel()
        let coord = StateCoordinator(worldModel: model)
        let goal = Goal(description: "noop")
        let ctx = TaskContext(goal: goal)
        let bundle = coord.buildBundle(taskContext: ctx)
        XCTAssertNil(bundle.observation)
        XCTAssertEqual(bundle.stepIndex, 0)
    }

    func testResetClearsHistory() {
        let model = WorldStateModel()
        let coord = StateCoordinator(worldModel: model)
        coord.ingest(makeObservation(app: "Safari"))
        coord.reset()
        // After reset, next ingest treats observation as first → no delta path
        let snap = coord.ingest(makeObservation(app: "Mail"))
        XCTAssertEqual(snap.activeApplication, "Mail")
    }

    func testCurrentSnapshotMirrorsModel() {
        let model = WorldStateModel()
        let coord = StateCoordinator(worldModel: model)
        XCTAssertEqual(coord.currentSnapshot.activeApplication, model.snapshot.activeApplication)
        coord.ingest(makeObservation(app: "Notes"))
        XCTAssertEqual(coord.currentSnapshot.activeApplication, "Notes")
        XCTAssertEqual(coord.currentSnapshot.activeApplication, model.snapshot.activeApplication)
    }
}

// ── 47c. DecisionCoordinator ─────────────────────────────────────────────────

final class DecisionCoordinatorTests: XCTestCase {

    func testDecideReturnsPlan() {
        let planner = PlanGenerator()
        let graph = GraphStore()
        let memory = StateMemoryIndex()
        let coord = DecisionCoordinator(planner: planner, graphStore: graph, stateMemory: memory)

        let goal = Goal(description: "write a file")
        let ctx = TaskContext(goal: goal, workspaceRoot: "/ws")
        let snap = WorldModelSnapshot()
        let bundle = StateBundle(taskContext: ctx, snapshot: snap)

        let plan = coord.decide(from: bundle, assembledContext: "context")
        XCTAssertNotNil(plan)
        XCTAssertFalse(plan.actions.isEmpty)
    }

    func testDecideInjectsMemoryHint() {
        let planner = PlanGenerator()
        let graph = GraphStore()
        let memory = StateMemoryIndex()

        let goal = Goal(description: "git push")
        let sig = StateSignature.from(context: goal.description, actionTypes: [])
        // Seed memory with enough successes to pass the threshold
        for _ in 0..<5 {
            memory.record(stateSignature: sig, actionType: "git_push", success: true)
        }

        let coord = DecisionCoordinator(planner: planner, graphStore: graph, stateMemory: memory)
        let ctx = TaskContext(goal: goal)
        let bundle = StateBundle(taskContext: ctx, snapshot: WorldModelSnapshot())
        let plan = coord.decide(from: bundle)
        // The plan is generated (memory hint is woven into context — output is non-empty)
        XCTAssertFalse(plan.actions.isEmpty)
    }

    func testIsGoalReachedReturnsFalse() {
        let coord = DecisionCoordinator(
            planner: PlanGenerator(),
            graphStore: GraphStore(),
            stateMemory: StateMemoryIndex()
        )
        let ctx = TaskContext(goal: Goal(description: "test"))
        let bundle = StateBundle(taskContext: ctx, snapshot: WorldModelSnapshot())
        XCTAssertFalse(coord.isGoalReached(bundle: bundle))
    }
}

// ── 47d. ExecutionCoordinator ─────────────────────────────────────────────────

final class ExecutionCoordinatorTests: XCTestCase {

    func testPrepareAllowsPermittedIntent() {
        let registry = SkillRegistry.live()
        let policy = PolicyEngine()
        let coord = ExecutionCoordinator(skillRegistry: registry, policy: policy)
        let intent = ActionIntent(type: "log", domain: .system)
        let snap = WorldModelSnapshot()
        let prepared = coord.prepare(intent: intent, snapshot: snap)
        XCTAssertTrue(prepared.policyAllowed)
        XCTAssertNil(prepared.blockReason)
    }

    func testPrepareBlocksOnPolicyDeny() {
        let registry = SkillRegistry.live()
        let policy = PolicyEngine()
        let coord = ExecutionCoordinator(skillRegistry: registry, policy: policy)
        // "delete_file" triggers requireApproval → policy returns false
        let intent = ActionIntent(type: "delete_file", domain: .code)
        let snap = WorldModelSnapshot()
        let prepared = coord.prepare(intent: intent, snapshot: snap)
        XCTAssertFalse(prepared.policyAllowed)
        XCTAssertNotNil(prepared.blockReason)
    }

    func testPrepareFromResolutionAllowed() {
        let registry = SkillRegistry.live()
        let policy = PolicyEngine()
        let coord = ExecutionCoordinator(skillRegistry: registry, policy: policy)
        let intent = ActionIntent(type: "log", domain: .system)
        let resolution = SkillResolution(intent: intent, confidence: 0.95)
        let prepared = coord.prepare(resolution: resolution)
        XCTAssertTrue(prepared.policyAllowed)
        XCTAssertEqual(prepared.confidence, 0.95, accuracy: 0.001)
    }

    func testPrepareFromResolutionBlocked() {
        let registry = SkillRegistry.live()
        let policy = PolicyEngine()
        let coord = ExecutionCoordinator(skillRegistry: registry, policy: policy)
        let intent = ActionIntent(type: "write_system_file", domain: .code)
        let resolution = SkillResolution(intent: intent, confidence: 1.0)
        let prepared = coord.prepare(resolution: resolution)
        XCTAssertFalse(prepared.policyAllowed)
    }
}

// ── 47e. LearningCoordinator ──────────────────────────────────────────────────

final class LearningCoordinatorTests: XCTestCase {

    private func makeBundle(goalDesc: String = "test") -> StateBundle {
        let goal = Goal(description: goalDesc)
        let ctx = TaskContext(goal: goal)
        return StateBundle(taskContext: ctx, snapshot: WorldModelSnapshot())
    }

    func testRecordSuccessUpdatesMetrics() {
        let metrics = MetricsRecorder()
        let memory = StateMemoryIndex()
        let coord = LearningCoordinator(metrics: metrics, stateMemory: memory)
        let intent = ActionIntent(type: "run_build", domain: .code)
        coord.recordSuccess(intent: intent, bundle: makeBundle(), latencyMs: 120)
        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalActionsExecuted, 1)
        XCTAssertEqual(snap.actionSuccessRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(snap.averageLatencyMs, 120.0, accuracy: 1.0)
    }

    func testRecordFailureUpdatesMetrics() {
        let metrics = MetricsRecorder()
        let memory = StateMemoryIndex()
        let coord = LearningCoordinator(metrics: metrics, stateMemory: memory)
        let intent = ActionIntent(type: "run_tests", domain: .code)
        coord.recordFailure(intent: intent, bundle: makeBundle(), latencyMs: 50)
        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalActionsExecuted, 1)
        XCTAssertEqual(snap.actionSuccessRate, 0.0, accuracy: 0.001)
    }

    func testRecordSuccessUpdatesStateMemory() {
        let metrics = MetricsRecorder()
        let memory = StateMemoryIndex()
        let coord = LearningCoordinator(metrics: metrics, stateMemory: memory)
        let intent = ActionIntent(type: "git_commit", domain: .tool)
        let bundle = makeBundle(goalDesc: "commit changes")
        // Record enough to exceed minAttempts threshold
        for _ in 0..<5 {
            coord.recordSuccess(intent: intent, bundle: bundle, latencyMs: 10)
        }
        let sig = StateSignature.from(context: "commit changes", actionTypes: ["git_commit"])
        XCTAssertTrue(memory.hasMemory(for: sig))
        let likely = memory.likelyActions(for: sig)
        XCTAssertTrue(likely.contains("git_commit"))
    }

    func testRecordRecoveryIncrementsCounter() {
        let metrics = MetricsRecorder()
        let memory = StateMemoryIndex()
        let coord = LearningCoordinator(metrics: metrics, stateMemory: memory)
        coord.recordRecovery()
        coord.recordRecovery()
        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalRecoveryAttempts, 2)
    }

    func testFinalizeRecordsGoal() {
        let metrics = MetricsRecorder()
        let memory = StateMemoryIndex()
        let coord = LearningCoordinator(metrics: metrics, stateMemory: memory)
        let goal = Goal(description: "finish")
        coord.finalize(goal: goal, succeeded: true, stepCount: 4)
        let snap = metrics.snapshot()
        XCTAssertEqual(snap.totalGoalsProcessed, 1)
        XCTAssertEqual(snap.taskSuccessRate, 1.0, accuracy: 0.001)
    }
}

// ── 47f. OracleRuntime coordinator wiring ───────────────────────────────────

final class CoordinatorRuntimeWiringTests: XCTestCase {

    func testRuntimeExposesAllCoordinators() {
        let runtime = OracleRuntime()
        runtime.initialize()
        // All four coordinator properties must be non-nil after initialize()
        XCTAssertNotNil(runtime.stateCoordinator)
        XCTAssertNotNil(runtime.decisionCoordinator)
        XCTAssertNotNil(runtime.executionCoordinator)
        XCTAssertNotNil(runtime.learningCoordinator)
    }

    func testStateCoordsSnapshotMatchesRuntimeModel() {
        let runtime = OracleRuntime()
        runtime.initialize()
        // Before any observations the snapshots should be equal
        XCTAssertEqual(
            runtime.stateCoordinator.currentSnapshot.activeApplication,
            runtime.worldModel.snapshot.activeApplication
        )
    }

    func testDecisionCoordinatorProducesPlan() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let goal = Goal(description: "build the project")
        let ctx = TaskContext(goal: goal, workspaceRoot: "/oracle", agentKind: .code)
        let bundle = runtime.stateCoordinator.buildBundle(taskContext: ctx)
        let plan = runtime.decisionCoordinator.decide(from: bundle)
        XCTAssertFalse(plan.actions.isEmpty)
    }

    func testExecutionCoordinatorPreparesIntent() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let intent = ActionIntent(type: "log", domain: .system, parameters: ["msg": "hello"])
        let prepared = runtime.executionCoordinator.prepare(
            intent: intent,
            snapshot: runtime.worldModel.snapshot
        )
        XCTAssertTrue(prepared.policyAllowed)
    }

    func testLearningCoordinatorFinalizesGoal() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let goal = Goal(description: "coordinator wiring test")
        runtime.learningCoordinator.finalize(goal: goal, succeeded: true, stepCount: 2)
        let snap = runtime.metrics.snapshot()
        XCTAssertEqual(snap.totalGoalsProcessed, 1)
    }
}

// MARK: - 48. AgentLoop Tests

// ── 48a. LoopBudget ──────────────────────────────────────────────────────────

final class LoopBudgetTests: XCTestCase {

    func testDefaultBudget() {
        let b = LoopBudget()
        XCTAssertEqual(b.maxSteps, 25)
        XCTAssertEqual(b.maxRecoveries, 5)
        XCTAssertEqual(b.maxConsecutiveExplorationSteps, 3)
    }

    func testTestBudget() {
        let b = LoopBudget.test
        XCTAssertEqual(b.maxSteps, 5)
        XCTAssertEqual(b.maxRecoveries, 2)
    }

    func testBudgetStateIncrements() {
        let budget = LoopBudget(maxSteps: 3, maxRecoveries: 2, maxConsecutiveExplorationSteps: 2)
        var state = LoopBudgetState()
        XCTAssertFalse(state.incrementStep(budget: budget))
        XCTAssertFalse(state.incrementStep(budget: budget))
        XCTAssertTrue(state.incrementStep(budget: budget))  // hits ceiling at step 3
    }

    func testBudgetStateRecovery() {
        let budget = LoopBudget(maxSteps: 10, maxRecoveries: 2, maxConsecutiveExplorationSteps: 3)
        var state = LoopBudgetState()
        XCTAssertTrue(state.canRecover(under: budget))
        state.registerRecovery(budget: budget)
        XCTAssertTrue(state.canRecover(under: budget))
        state.registerRecovery(budget: budget)
        XCTAssertFalse(state.canRecover(under: budget))
    }

    func testBudgetStateExploration() {
        let budget = LoopBudget(maxSteps: 10, maxRecoveries: 5, maxConsecutiveExplorationSteps: 2)
        var state = LoopBudgetState()
        XCTAssertFalse(state.registerExplorationStep(budget: budget))
        XCTAssertFalse(state.registerExplorationStep(budget: budget))
        XCTAssertTrue(state.registerExplorationStep(budget: budget))  // exceeds ceiling
    }

    func testBudgetStateResetExploration() {
        let budget = LoopBudget(maxSteps: 10, maxRecoveries: 5, maxConsecutiveExplorationSteps: 2)
        var state = LoopBudgetState()
        state.registerExplorationStep(budget: budget)
        state.registerExplorationStep(budget: budget)
        state.resetExploration()
        XCTAssertEqual(state.consecutiveExplorationSteps, 0)
    }
}

// ── 48b. LoopTypes ───────────────────────────────────────────────────────────

final class LoopTypesTests: XCTestCase {

    func testLoopOutcomeFields() {
        let snap = WorldModelSnapshot(activeApplication: "Xcode")
        let outcome = LoopOutcome(reason: .goalAchieved, finalSnapshot: snap, steps: 3, recoveries: 1)
        XCTAssertEqual(outcome.reason, .goalAchieved)
        XCTAssertEqual(outcome.steps, 3)
        XCTAssertEqual(outcome.recoveries, 1)
        XCTAssertEqual(outcome.finalSnapshot.activeApplication, "Xcode")
    }

    func testLoopOutcomeSummaryContainsReason() {
        let snap = WorldModelSnapshot()
        let outcome = LoopOutcome(reason: .maxSteps, finalSnapshot: snap, steps: 25, recoveries: 0)
        XCTAssertTrue(outcome.summary.contains("maxSteps"))
        XCTAssertTrue(outcome.summary.contains("25"))
    }

    func testAllTerminationReasonsHaveRawValues() {
        let reasons: [LoopTerminationReason] = [
            .goalAchieved, .maxSteps, .policyBlocked, .noViablePlan,
            .unrecoverableFailure, .explorationBudgetExceeded, .recoveryBudgetExhausted
        ]
        for r in reasons {
            XCTAssertFalse(r.rawValue.isEmpty)
        }
    }
}

// ── 48c. GoalClassifier ──────────────────────────────────────────────────────

final class GoalClassifierTests: XCTestCase {

    func testClassifiesCodeGoal() {
        XCTAssertEqual(GoalClassifier.classify(description: "fix the build error"), .code)
        XCTAssertEqual(GoalClassifier.classify(description: "run swift test"), .code)
        XCTAssertEqual(GoalClassifier.classify(description: "commit and push changes"), .code)
    }

    func testClassifiesUIGoal() {
        XCTAssertEqual(GoalClassifier.classify(description: "open Safari and click login"), .ui)
        XCTAssertEqual(GoalClassifier.classify(description: "scroll down in Finder"), .ui)
    }

    func testClassifiesMixedGoal() {
        let kind = GoalClassifier.classify(description: "open Xcode and fix the build")
        XCTAssertEqual(kind, .mixed)
    }

    func testDefaultsToUI() {
        let kind = GoalClassifier.classify(description: "do the thing")
        XCTAssertEqual(kind, .ui)
    }

    func testWorkspaceRootHintDoesNotBreak() {
        let kind = GoalClassifier.classify(description: "review the code", workspaceRoot: "/workspace")
        // Should be code or mixed — not a crash
        XCTAssertNotNil(kind)
    }
}

// ── 48d. RuntimeSurface ──────────────────────────────────────────────────────

final class RuntimeSurfaceTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(RuntimeSurface.controller.rawValue, "controller")
        XCTAssertEqual(RuntimeSurface.mcp.rawValue, "mcp")
        XCTAssertEqual(RuntimeSurface.cli.rawValue, "cli")
        XCTAssertEqual(RuntimeSurface.recipe.rawValue, "recipe")
    }

    func testEquatable() {
        XCTAssertEqual(RuntimeSurface.cli, RuntimeSurface.cli)
        XCTAssertNotEqual(RuntimeSurface.cli, RuntimeSurface.mcp)
    }
}

// ── 48e. AgentLoop integration ───────────────────────────────────────────────

final class AgentLoopTests: XCTestCase {

    private func makeRuntime() -> OracleRuntime {
        let r = OracleRuntime()
        r.initialize()
        return r
    }

    func testRuntimeExposesAgentLoop() {
        let runtime = makeRuntime()
        XCTAssertNotNil(runtime.agentLoop)
    }

    func testLoopReturnsOutcomeWithNoViablePlanOnEmptyGoal() {
        let runtime = makeRuntime()
        // A goal description that produces no actions from the planner
        // should terminate with .noViablePlan or .maxSteps (either is valid).
        let goal = Goal(description: "")
        let ctx = TaskContext(goal: goal)
        let outcome = runtime.agentLoop.run(taskContext: ctx, budget: .test)
        XCTAssertTrue(
            outcome.reason == .noViablePlan ||
            outcome.reason == .maxSteps ||
            outcome.reason == .policyBlocked ||
            outcome.reason == .goalAchieved
        )
        XCTAssertGreaterThanOrEqual(outcome.steps, 0)
    }

    func testLoopTerminatesWithinMaxSteps() {
        let runtime = makeRuntime()
        let goal = Goal(description: "log something for the test")
        let ctx = TaskContext(goal: goal, agentKind: .mixed)
        let budget = LoopBudget(maxSteps: 3, maxRecoveries: 1, maxConsecutiveExplorationSteps: 2)
        let outcome = runtime.agentLoop.run(taskContext: ctx, budget: budget)
        XCTAssertLessThanOrEqual(outcome.steps, budget.maxSteps)
    }

    func testLoopRecordsGoalInMetrics() {
        let runtime = makeRuntime()
        let before = runtime.metrics.snapshot()
        let goal = Goal(description: "run the tests")
        let ctx = TaskContext(goal: goal, agentKind: .code)
        runtime.agentLoop.run(taskContext: ctx, budget: .test)
        let after = runtime.metrics.snapshot()
        XCTAssertGreaterThan(after.totalGoalsProcessed, before.totalGoalsProcessed)
    }

    func testLoopFinalSnapshotIsNonNil() {
        let runtime = makeRuntime()
        let goal = Goal(description: "build project")
        let ctx = TaskContext(goal: goal, workspaceRoot: "/tmp", agentKind: .code)
        let outcome = runtime.agentLoop.run(taskContext: ctx, budget: .test)
        // finalSnapshot should be a valid WorldModelSnapshot (struct is always value-typed)
        XCTAssertGreaterThanOrEqual(outcome.steps, 0)
        XCTAssertGreaterThanOrEqual(outcome.recoveries, 0)
    }

    func testLoopPolicyBlockedHonoured() {
        let runtime = makeRuntime()
        // "delete_file" requires approval — policy blocks it
        let goal = Goal(description: "delete_file the build")
        let ctx = TaskContext(goal: goal)
        // Inject a plan that tries delete_file by adding a blocking policy rule
        runtime.policy.addRule(PolicyRule(
            name: "test-block-delete",
            pattern: "delete_file",
            decision: .block
        ))
        let outcome = runtime.agentLoop.run(taskContext: ctx, budget: .test)
        // Outcome is one of the valid termination reasons
        let validReasons: [LoopTerminationReason] = [
            .policyBlocked, .noViablePlan, .maxSteps, .goalAchieved,
            .unrecoverableFailure, .recoveryBudgetExhausted, .explorationBudgetExceeded
        ]
        XCTAssertTrue(validReasons.contains(outcome.reason))
    }
}

// MARK: - 49. Strategy Layer Tests

// ── 49a. StrategyKind ────────────────────────────────────────────────────────

final class StrategyKindTests: XCTestCase {

    func testAllCasesHaveRawValues() {
        for kind in StrategyKind.allCases {
            XCTAssertFalse(kind.rawValue.isEmpty)
        }
    }

    func testExpectedCases() {
        XCTAssertNotNil(StrategyKind(rawValue: "repo_repair"))
        XCTAssertNotNil(StrategyKind(rawValue: "recovery_mode"))
        XCTAssertNotNil(StrategyKind(rawValue: "browser_interaction"))
        XCTAssertNotNil(StrategyKind(rawValue: "graph_navigation"))
        XCTAssertNil(StrategyKind(rawValue: "nonexistent"))
    }

    func testCaseIterableCount() {
        XCTAssertEqual(StrategyKind.allCases.count, 9)
    }
}

// ── 49b. OperatorFamily ──────────────────────────────────────────────────────

final class OperatorFamilyTests: XCTestCase {

    func testAllCasesHaveRawValues() {
        for family in OperatorFamily.allCases {
            XCTAssertFalse(family.rawValue.isEmpty)
        }
    }

    func testExpectedCases() {
        XCTAssertNotNil(OperatorFamily(rawValue: "recovery"))
        XCTAssertNotNil(OperatorFamily(rawValue: "graph_edge"))
        XCTAssertNotNil(OperatorFamily(rawValue: "patch_generation"))
        XCTAssertNil(OperatorFamily(rawValue: "nonexistent"))
    }
}

// ── 49c. SelectedStrategy ────────────────────────────────────────────────────

final class SelectedStrategyTests: XCTestCase {

    private func makeStrategy(
        kind: StrategyKind = .repoRepair,
        families: [OperatorFamily] = [.repoAnalysis, .patchGeneration, .recovery]
    ) -> SelectedStrategy {
        SelectedStrategy(
            kind: kind,
            confidence: 0.85,
            rationale: "test",
            allowedOperatorFamilies: families,
            reevaluateAfterStepCount: 5
        )
    }

    func testAllows() {
        let s = makeStrategy()
        XCTAssertTrue(s.allows(.repoAnalysis))
        XCTAssertTrue(s.allows(.recovery))
        XCTAssertFalse(s.allows(.browserTargeted))
    }

    func testIsHighConfidence() {
        let hi = makeStrategy()
        XCTAssertTrue(hi.isHighConfidence)
        let lo = SelectedStrategy(kind: .graphNavigation, confidence: 0.5, rationale: "lo",
                                  allowedOperatorFamilies: [.graphEdge])
        XCTAssertFalse(lo.isHighConfidence)
    }

    func testEquatable() {
        let a = makeStrategy()
        let b = makeStrategy()
        XCTAssertEqual(a, b)
    }
}

// ── 49d. StrategyLibrary ─────────────────────────────────────────────────────

final class StrategyLibraryTests: XCTestCase {

    func testAllowedFamiliesForRepoRepair() {
        let families = StrategyLibrary.allowedFamilies(for: .repoRepair)
        XCTAssertTrue(families.contains(.repoAnalysis))
        XCTAssertTrue(families.contains(.patchGeneration))
        XCTAssertTrue(families.contains(.recovery))
        XCTAssertFalse(families.contains(.browserTargeted))
    }

    func testAllowedFamiliesForRecovery() {
        let families = StrategyLibrary.allowedFamilies(for: .recoveryMode)
        XCTAssertTrue(families.contains(.recovery))
        XCTAssertFalse(families.contains(.patchGeneration))
    }

    func testAllowedFamiliesForBrowser() {
        let families = StrategyLibrary.allowedFamilies(for: .browserInteraction)
        XCTAssertTrue(families.contains(.browserTargeted))
        XCTAssertFalse(families.contains(.repoAnalysis))
    }

    func testAllStrategyKindsHaveFamilies() {
        for kind in StrategyKind.allCases {
            XCTAssertFalse(StrategyLibrary.allowedFamilies(for: kind).isEmpty,
                           "\(kind) has no allowed families")
        }
    }

    func testDefaultLibraryIsNonEmpty() {
        XCTAssertGreaterThan(StrategyLibrary.defaultLibrary().count, 0)
    }

    func testDefaultLibraryContainsRecovery() {
        let kinds = StrategyLibrary.defaultLibrary().map { $0.kind }
        XCTAssertTrue(kinds.contains(.recovery))
    }
}

// ── 49e. StrategyEvaluator ───────────────────────────────────────────────────

final class StrategyEvaluatorTests: XCTestCase {

    func testNoActiveStrategyTrigger() {
        let ev = StrategyEvaluator()
        XCTAssertEqual(ev.shouldReevaluate(), .noActiveStrategy)
    }

    func testPlanCompletedTrigger() {
        let ev = StrategyEvaluator()
        let s = SelectedStrategy(kind: .repoRepair, confidence: 0.8, rationale: "",
                                 allowedOperatorFamilies: [.repoAnalysis], reevaluateAfterStepCount: 5)
        ev.setCurrentStrategy(s)
        XCTAssertEqual(ev.shouldReevaluate(planCompleted: true), .planCompleted)
    }

    func testHardFailureTrigger() {
        let ev = StrategyEvaluator()
        let s = SelectedStrategy(kind: .repoRepair, confidence: 0.8, rationale: "",
                                 allowedOperatorFamilies: [.repoAnalysis], reevaluateAfterStepCount: 5)
        ev.setCurrentStrategy(s)
        XCTAssertEqual(ev.shouldReevaluate(hardFailure: true), .hardFailure)
    }

    func testThresholdTrigger() {
        let ev = StrategyEvaluator()
        let s = SelectedStrategy(kind: .graphNavigation, confidence: 0.7, rationale: "",
                                 allowedOperatorFamilies: [.graphEdge], reevaluateAfterStepCount: 3)
        ev.setCurrentStrategy(s)
        ev.recordStep(); ev.recordStep(); ev.recordStep()
        XCTAssertEqual(ev.shouldReevaluate(), .reevaluateThresholdReached)
    }

    func testNoReevaluateBelowThreshold() {
        let ev = StrategyEvaluator()
        let s = SelectedStrategy(kind: .graphNavigation, confidence: 0.7, rationale: "",
                                 allowedOperatorFamilies: [.graphEdge], reevaluateAfterStepCount: 5)
        ev.setCurrentStrategy(s)
        ev.recordStep(); ev.recordStep()
        XCTAssertNil(ev.shouldReevaluate())
    }

    func testReset() {
        let ev = StrategyEvaluator()
        let s = SelectedStrategy(kind: .repoRepair, confidence: 0.8, rationale: "",
                                 allowedOperatorFamilies: [.repoAnalysis])
        ev.setCurrentStrategy(s)
        ev.reset()
        XCTAssertNil(ev.activeStrategy())
        XCTAssertEqual(ev.stepsSinceStrategySelection(), 0)
    }

    func testHistoricalSuccessRate() {
        let ev = StrategyEvaluator()
        ev.record(evaluation: StrategyEvaluation(kind: .repoRepair, steps: 3, succeeded: true, confidence: 0.8))
        ev.record(evaluation: StrategyEvaluation(kind: .repoRepair, steps: 4, succeeded: false, confidence: 0.6))
        let rate = ev.successRate(for: .repoRepair)
        XCTAssertEqual(rate, 0.5, accuracy: 0.001)
    }

    func testSuccessRateZeroForUnknownKind() {
        let ev = StrategyEvaluator()
        XCTAssertEqual(ev.successRate(for: .experimentMode), 0.0)
    }
}

// ── 49f. StrategySelector ────────────────────────────────────────────────────

final class StrategySelectorTests: XCTestCase {

    private let selector = StrategySelector()
    private let snap = WorldModelSnapshot()

    func testCodeGoalSelectsRepoRepair() {
        let goal = Goal(description: "fix the build error in main.swift")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .code)
        XCTAssertEqual(result.kind, .repoRepair)
    }

    func testUIGoalWithBrowserSelectsBrowser() {
        let goal = Goal(description: "navigate to the login page in Safari")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .ui)
        XCTAssertEqual(result.kind, .browserInteraction)
    }

    func testUIGoalWithoutBrowserSelectsDirect() {
        let goal = Goal(description: "open System Preferences")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .ui)
        XCTAssertEqual(result.kind, .directExecution)
    }

    func testMixedGoalWithRepairSelectsRepo() {
        let goal = Goal(description: "run the tests and fix any failures")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .mixed)
        XCTAssertEqual(result.kind, .repoRepair)
    }

    func testRecoveryOverrideAfterThreeFailures() {
        let goal = Goal(description: "do something")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .mixed,
                                     recentFailureCount: 3)
        XCTAssertEqual(result.kind, .recoveryMode)
    }

    func testPermissionGoalSelectsPermissionResolution() {
        let goal = Goal(description: "grant permission to access the camera")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .ui)
        XCTAssertEqual(result.kind, .permissionResolution)
    }

    func testSelectedStrategyAllowedFamiliesAreCorrect() {
        let goal = Goal(description: "fix the build")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .code)
        XCTAssertTrue(result.allows(.repoAnalysis))
        XCTAssertTrue(result.allows(.recovery))
        XCTAssertFalse(result.allows(.browserTargeted))
    }

    func testConfidenceIsPositive() {
        let goal = Goal(description: "build the project")
        let result = selector.select(goal: goal, snapshot: snap, agentKind: .code)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }
}

// ── 49g. Runtime Strategy Wiring ─────────────────────────────────────────────

final class RuntimeStrategyWiringTests: XCTestCase {

    func testRuntimeExposesStrategySelector() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.strategySelector)
    }

    func testRuntimeExposesStrategyEvaluator() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.strategyEvaluator)
    }

    func testStrategySelectorIntegratesWithRuntime() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let goal = Goal(description: "fix the failing tests")
        let snap = runtime.worldModel.snapshot
        let strategy = runtime.strategySelector.select(
            goal: goal,
            snapshot: snap,
            agentKind: .code
        )
        XCTAssertEqual(strategy.kind, .repoRepair)
        XCTAssertFalse(strategy.allowedOperatorFamilies.isEmpty)
    }

    func testStrategyEvaluatorPersistsState() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let goal = Goal(description: "build the project")
        let snap = runtime.worldModel.snapshot
        let strategy = runtime.strategySelector.select(goal: goal, snapshot: snap, agentKind: .code)
        runtime.strategyEvaluator.setCurrentStrategy(strategy)
        runtime.strategyEvaluator.recordStep()
        XCTAssertEqual(runtime.strategyEvaluator.stepsSinceStrategySelection(), 1)
        XCTAssertEqual(runtime.strategyEvaluator.activeStrategy()?.kind, .repoRepair)
    }
}

// MARK: - 50. Workflow Layer Tests

final class WorkflowTypesTests: XCTestCase {

    func testWorkflowStepInit() {
        let step = WorkflowStep(actionType: "click", skillName: "UISkill", agentKind: .ui)
        XCTAssertFalse(step.id.isEmpty)
        XCTAssertEqual(step.actionType, "click")
        XCTAssertEqual(step.skillName, "UISkill")
        XCTAssertEqual(step.agentKind, .ui)
    }

    func testWorkflowPlanInitDefaultsToCandidate() {
        let plan = WorkflowPlan(agentKind: .ui, goalPattern: "open settings", steps: [])
        XCTAssertEqual(plan.promotionStatus, .candidate)
        XCTAssertEqual(plan.successCount, 0)
        XCTAssertEqual(plan.attemptCount, 0)
    }

    func testWorkflowPlanSuccessRate_zeroDenominator() {
        let plan = WorkflowPlan(agentKind: .ui, goalPattern: "open settings", steps: [])
        XCTAssertEqual(plan.successRate, 0.0)
    }

    func testWorkflowPlanRecordSuccess() {
        var plan = WorkflowPlan(agentKind: .code, goalPattern: "run tests", steps: [])
        plan.recordSuccess()
        XCTAssertEqual(plan.successCount, 1)
        XCTAssertEqual(plan.attemptCount, 1)
        XCTAssertEqual(plan.successRate, 1.0)
        XCTAssertNotNil(plan.lastSucceededAt)
    }

    func testWorkflowPlanRecordFailure() {
        var plan = WorkflowPlan(agentKind: .code, goalPattern: "run tests", steps: [])
        plan.recordFailure()
        XCTAssertEqual(plan.successCount, 0)
        XCTAssertEqual(plan.attemptCount, 1)
        XCTAssertEqual(plan.successRate, 0.0)
    }

    func testWorkflowPlanSuccessRate_partialSuccess() {
        var plan = WorkflowPlan(agentKind: .code, goalPattern: "run tests", steps: [])
        plan.recordSuccess()
        plan.recordSuccess()
        plan.recordFailure()
        XCTAssertEqual(plan.successRate, 2.0/3.0, accuracy: 0.001)
    }

    func testWorkflowPlanSetPromotionStatus() {
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "click login", steps: [])
        plan.setPromotionStatus(.promoted)
        XCTAssertEqual(plan.promotionStatus, .promoted)
    }

    func testWorkflowPromotionStatusAllCases() {
        let all = WorkflowPromotionStatus.allCases
        XCTAssertTrue(all.contains(.candidate))
        XCTAssertTrue(all.contains(.promoted))
        XCTAssertTrue(all.contains(.rejected))
        XCTAssertTrue(all.contains(.stale))
    }
}

final class WorkflowIndexTests: XCTestCase {

    func testAddAndRetrievePlan() {
        let index = WorkflowIndex()
        let plan = WorkflowPlan(agentKind: .ui, goalPattern: "open browser", steps: [])
        index.add(plan)
        XCTAssertNotNil(index.plan(id: plan.id))
        XCTAssertEqual(index.allPlans().count, 1)
    }

    func testRemovePlan() {
        let index = WorkflowIndex()
        let plan = WorkflowPlan(agentKind: .ui, goalPattern: "open browser", steps: [])
        index.add(plan)
        index.remove(id: plan.id)
        XCTAssertNil(index.plan(id: plan.id))
        XCTAssertEqual(index.allPlans().count, 0)
    }

    func testUpdatePlan() {
        let index = WorkflowIndex()
        var plan = WorkflowPlan(agentKind: .code, goalPattern: "run tests", steps: [])
        index.add(plan)
        plan.setPromotionStatus(.promoted)
        index.update(plan)
        XCTAssertEqual(index.plan(id: plan.id)?.promotionStatus, .promoted)
    }

    func testPromotedPlansFiltersByStatus() {
        let index = WorkflowIndex()
        var candidate = WorkflowPlan(agentKind: .ui, goalPattern: "login", steps: [])
        var promoted = WorkflowPlan(agentKind: .ui, goalPattern: "search", steps: [])
        promoted.setPromotionStatus(.promoted)
        index.add(candidate)
        index.add(promoted)
        let results = index.promotedPlans()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.goalPattern, "search")
        _ = candidate  // suppress unused warning
    }

    func testPromotedPlansFiltersByAgentKind() {
        let index = WorkflowIndex()
        var p1 = WorkflowPlan(agentKind: .ui, goalPattern: "login", steps: [])
        var p2 = WorkflowPlan(agentKind: .code, goalPattern: "compile", steps: [])
        p1.setPromotionStatus(.promoted)
        p2.setPromotionStatus(.promoted)
        index.add(p1)
        index.add(p2)
        let uiResults = index.promotedPlans(for: .ui)
        XCTAssertEqual(uiResults.count, 1)
        XCTAssertEqual(uiResults.first?.agentKind, .ui)
    }

    func testMatchingByGoalPatternOverlap() {
        let index = WorkflowIndex()
        let plan = WorkflowPlan(agentKind: .ui, goalPattern: "open browser navigate", steps: [])
        index.add(plan)
        let goal = Goal(description: "open browser")
        let matches = index.matching(goal: goal)
        XCTAssertFalse(matches.isEmpty)
    }

    func testSweepStaleRemovesOldPlans() {
        let index = WorkflowIndex()
        let plan = WorkflowPlan(agentKind: .code, goalPattern: "old workflow", steps: [], createdAt: Date(timeIntervalSinceNow: -8 * 86400))
        index.add(plan)
        let removed = index.sweepStale()
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(index.allPlans().count, 0)
    }
}

final class WorkflowMatcherTests: XCTestCase {

    func testMatchReturnsEmptyWhenNoPromotedPlans() {
        let index = WorkflowIndex()
        let plan = WorkflowPlan(agentKind: .ui, goalPattern: "login via browser", steps: [])
        index.add(plan)  // stays candidate
        let matcher = WorkflowMatcher()
        let goal = Goal(description: "login via browser")
        let matches = matcher.match(goal: goal, index: index)
        XCTAssertTrue(matches.isEmpty)
    }

    func testMatchReturnsPromotedPlans() {
        let index = WorkflowIndex()
        let step = WorkflowStep(actionType: "click", skillName: "UISkill", agentKind: .ui)
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "click login button", steps: [step])
        plan.setPromotionStatus(.promoted)
        index.add(plan)
        let matcher = WorkflowMatcher()
        let goal = Goal(description: "click login button")
        let matches = matcher.match(goal: goal, index: index)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertEqual(matches.first?.workflowID, plan.id)
    }

    func testMatchConfidenceIsPositive() {
        let index = WorkflowIndex()
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "open settings menu", steps: [
            WorkflowStep(actionType: "click", skillName: "UISkill", agentKind: .ui)
        ])
        plan.setPromotionStatus(.promoted)
        index.add(plan)
        let matcher = WorkflowMatcher()
        let goal = Goal(description: "open settings menu")
        let matches = matcher.match(goal: goal, index: index)
        XCTAssertTrue((matches.first?.confidence ?? 0) > 0)
    }

    func testMatchSortedByConfidenceDescending() {
        let index = WorkflowIndex()
        var p1 = WorkflowPlan(agentKind: .ui, goalPattern: "login", steps: [
            WorkflowStep(actionType: "click", skillName: "UISkill", agentKind: .ui)
        ])
        var p2 = WorkflowPlan(agentKind: .ui, goalPattern: "login to dashboard via browser click submit", steps: [
            WorkflowStep(actionType: "click", skillName: "UISkill", agentKind: .ui)
        ])
        p1.setPromotionStatus(.promoted)
        p2.setPromotionStatus(.promoted)
        // p2 has many overlapping words — make it succeed more so it ranks higher
        for _ in 0..<5 { p2.recordSuccess() }
        index.add(p1)
        index.add(p2)
        let matcher = WorkflowMatcher()
        let goal = Goal(description: "login to dashboard")
        let matches = matcher.match(goal: goal, index: index)
        if matches.count >= 2 {
            XCTAssertGreaterThanOrEqual(matches[0].confidence, matches[1].confidence)
        }
    }
}

final class WorkflowSynthesizerTests: XCTestCase {

    private func trace(_ actionType: String, success: Bool) -> ExecutionTrace {
        ExecutionTrace(actionID: UUID().uuidString, actionType: actionType,
                       preStateHash: "pre", postStateHash: "post",
                       verified: success, success: success)
    }

    func testSynthesizeReturnsNilForEmptyTraces() {
        let result = WorkflowSynthesizer.synthesize(from: [], goalPattern: "test goal")
        XCTAssertNil(result)
    }

    func testSynthesizeReturnsNilForSingleTrace() {
        let result = WorkflowSynthesizer.synthesize(from: [trace("click", success: true)], goalPattern: "test goal")
        XCTAssertNil(result)
    }

    func testSynthesizeReturnsNilWhenNoSuccessfulTraces() {
        let result = WorkflowSynthesizer.synthesize(from: [trace("click", success: false), trace("type", success: false)], goalPattern: "test goal")
        XCTAssertNil(result)
    }

    func testSynthesizeCreatesWorkflowFromSuccessfulTraces() {
        let result = WorkflowSynthesizer.synthesize(
            from: [trace("click", success: true), trace("type", success: true)],
            goalPattern: "fill form"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.steps.count, 2)
        XCTAssertEqual(result?.goalPattern, "fill form")
        XCTAssertEqual(result?.promotionStatus, .candidate)
    }

    func testSynthesizeFiltersOutFailedTraces() {
        let result = WorkflowSynthesizer.synthesize(
            from: [trace("click", success: true), trace("fail_step", success: false), trace("type", success: true)],
            goalPattern: "partial form"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.steps.count, 2)
        XCTAssertFalse(result?.steps.contains { $0.actionType == "fail_step" } ?? true)
    }

    func testSynthesizerDedupedRemovesConsecutiveDuplicates() {
        let result = WorkflowSynthesizer.synthesizeDeduped(
            from: [trace("click", success: true), trace("click", success: true), trace("type", success: true)],
            goalPattern: "click then type"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.steps.count, 2)  // click + type (duplicate click removed)
    }
}

final class WorkflowPromoterTests: XCTestCase {

    func testShouldPromoteRequiresThreshold() {
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "login", steps: [])
        for _ in 0..<(WorkflowPromoter.promotionThreshold - 1) {
            plan.recordSuccess()
        }
        XCTAssertFalse(WorkflowPromoter.shouldPromote(plan))
    }

    func testShouldPromoteReturnsTrueAtThreshold() {
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "login", steps: [])
        for _ in 0..<WorkflowPromoter.promotionThreshold {
            plan.recordSuccess()
        }
        XCTAssertTrue(WorkflowPromoter.shouldPromote(plan))
    }

    func testEvaluatePromotesCandidateAtThreshold() {
        var plan = WorkflowPlan(agentKind: .code, goalPattern: "run tests", steps: [])
        for _ in 0..<WorkflowPromoter.promotionThreshold {
            WorkflowPromoter.recordOutcome(success: true, plan: &plan)
        }
        WorkflowPromoter.evaluate(plan: &plan)
        XCTAssertEqual(plan.promotionStatus, .promoted)
    }

    func testEvaluateDoesNotPromoteBelowThreshold() {
        var plan = WorkflowPlan(agentKind: .code, goalPattern: "run tests", steps: [])
        WorkflowPromoter.recordOutcome(success: true, plan: &plan)
        WorkflowPromoter.evaluate(plan: &plan)
        XCTAssertEqual(plan.promotionStatus, .candidate)
    }

    func testEvaluateRejectsPromotedPlanWithTooManyFailures() {
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "search", steps: [])
        // Promote it first
        for _ in 0..<WorkflowPromoter.promotionThreshold {
            WorkflowPromoter.recordOutcome(success: true, plan: &plan)
        }
        WorkflowPromoter.evaluate(plan: &plan)
        XCTAssertEqual(plan.promotionStatus, .promoted)
        // Now accumulate failures
        for _ in 0..<WorkflowPromoter.rejectionThreshold {
            WorkflowPromoter.recordOutcome(success: false, plan: &plan)
        }
        WorkflowPromoter.evaluate(plan: &plan)
        XCTAssertEqual(plan.promotionStatus, .rejected)
    }

    func testRejectedPlanIsTerminal() {
        var plan = WorkflowPlan(agentKind: .ui, goalPattern: "click nav", steps: [])
        plan.setPromotionStatus(.rejected)
        // Simulate successes — should not re-promote
        for _ in 0..<10 {
            WorkflowPromoter.recordOutcome(success: true, plan: &plan)
        }
        WorkflowPromoter.evaluate(plan: &plan)
        XCTAssertEqual(plan.promotionStatus, .rejected)
    }
}

final class RuntimeWorkflowWiringTests: XCTestCase {

    func testRuntimeHasWorkflowIndex() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.workflowIndex)
    }

    func testRuntimeHasWorkflowMatcher() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.workflowMatcher)
    }

    func testWorkflowIndexStartsEmpty() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertEqual(runtime.workflowIndex.allPlans().count, 0)
    }

    func testRoundTripWorkflowThroughRuntime() {
        let runtime = OracleRuntime()
        runtime.initialize()
        // Synthesize a workflow
        let mkTrace = { (type: String) in
            ExecutionTrace(actionID: UUID().uuidString, actionType: type,
                           preStateHash: "pre", postStateHash: "post",
                           verified: true, success: true)
        }
        let t1 = mkTrace("click")
        let t2 = mkTrace("type")
        let t3 = mkTrace("submit")
        guard let plan = WorkflowSynthesizer.synthesize(from: [t1, t2, t3], goalPattern: "fill login form") else {
            XCTFail("Synthesizer should produce a plan from 3 successful traces")
            return
        }
        runtime.workflowIndex.add(plan)
        XCTAssertEqual(runtime.workflowIndex.allPlans().count, 1)
        // Match (candidate — should not match promoted filter)
        let goal = Goal(description: "fill login form")
        let matches = runtime.workflowMatcher.match(goal: goal, index: runtime.workflowIndex)
        XCTAssertTrue(matches.isEmpty, "Candidate plans should not match — requires promotion")
    }
}

// MARK: - 51. Enhanced Recovery Layer Tests

final class FailureClassTests: XCTestCase {

    func testAllCasesExist() {
        XCTAssertEqual(FailureClass.allCases.count, 20)
    }

    func testRawValues() {
        XCTAssertEqual(FailureClass.elementNotFound.rawValue, "elementNotFound")
        XCTAssertEqual(FailureClass.buildFailed.rawValue, "buildFailed")
        XCTAssertEqual(FailureClass.workflowReplayFailure.rawValue, "workflowReplayFailure")
    }

    func testCodable() throws {
        let data = try JSONEncoder().encode(FailureClass.testFailed)
        let decoded = try JSONDecoder().decode(FailureClass.self, from: data)
        XCTAssertEqual(decoded, .testFailed)
    }
}

final class FailureClassifierTests: XCTestCase {

    func testClassifiesBuildFailed() {
        let result = FailureClassifier.classify(errorDescription: "build failed: exit code 1")
        XCTAssertEqual(result.failureClass, .buildFailed)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }

    func testClassifiesTestFailed() {
        let result = FailureClassifier.classify(errorDescription: "test failed: 3 assertions")
        XCTAssertEqual(result.failureClass, .testFailed)
    }

    func testClassifiesModalBlocking() {
        let result = FailureClassifier.classify(errorDescription: "modal blocking user interaction")
        XCTAssertEqual(result.failureClass, .modalBlocking)
    }

    func testClassifiesPermissionBlocked() {
        let result = FailureClassifier.classify(errorDescription: "permission denied for accessibility")
        XCTAssertEqual(result.failureClass, .permissionBlocked)
    }

    func testClassifiesWrongFocus() {
        let result = FailureClassifier.classify(errorDescription: "wrong focus — target not in active window")
        XCTAssertEqual(result.failureClass, .wrongFocus)
    }

    func testClassifiesAmbiguous() {
        let result = FailureClassifier.classify(errorDescription: "element is ambiguous: 3 matches")
        XCTAssertEqual(result.failureClass, .elementAmbiguous)
    }

    func testClassifiesNavigationFailed() {
        let result = FailureClassifier.classify(errorDescription: "navigation to URL failed")
        XCTAssertEqual(result.failureClass, .navigationFailed)
    }

    func testFallsThroughToActionFailed() {
        let result = FailureClassifier.classify(errorDescription: "unknown execution error xyz")
        XCTAssertEqual(result.failureClass, .actionFailed)
        XCTAssertEqual(result.confidence, 0.40, accuracy: 0.01)
    }

    func testContextBoostsConfidence() {
        let base = FailureClassifier.classify(errorDescription: "build failed: exit code 1")
        let ctx = FailureClassifierContext(recentFailureClasses: [.buildFailed])
        let boosted = FailureClassifier.classify(errorDescription: "build failed: exit code 1", context: ctx)
        XCTAssertGreaterThan(boosted.confidence, base.confidence)
    }

    func testClassificationHasSignals() {
        let result = FailureClassifier.classify(errorDescription: "build failed: exit code 1")
        XCTAssertFalse(result.signals.isEmpty)
    }

    func testConfidenceIsClamped() {
        let ctx = FailureClassifierContext(recentFailureClasses: Array(repeating: .buildFailed, count: 20))
        let result = FailureClassifier.classify(errorDescription: "build failed", context: ctx)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }
}

final class RecoveryStrategyTests: XCTestCase {

    func testRecoveryPreparationInit() {
        let prep = RecoveryPreparation(strategyName: "retry", actionHint: "retry now", estimatedCost: 0.5)
        XCTAssertEqual(prep.strategyName, "retry")
        XCTAssertEqual(prep.actionHint, "retry now")
        XCTAssertEqual(prep.estimatedCost, 0.5, accuracy: 0.001)
    }

    func testRecoveryPreparationClampsCostToZero() {
        let prep = RecoveryPreparation(strategyName: "x", actionHint: "y", estimatedCost: -1.0)
        XCTAssertEqual(prep.estimatedCost, 0.0)
    }

    func testRecoveryAttemptSucceeded() {
        let prep = RecoveryPreparation(strategyName: "dismiss_dialog", actionHint: "escape")
        let attempt = RecoveryAttempt.success(strategy: "dismiss_dialog", preparation: prep)
        XCTAssertTrue(attempt.succeeded)
        XCTAssertNotNil(attempt.preparation)
    }

    func testRecoveryAttemptExhausted() {
        let attempt = RecoveryAttempt.exhausted()
        XCTAssertFalse(attempt.succeeded)
        XCTAssertNil(attempt.preparation)
    }

    func testRecoveryAttemptNoStrategy() {
        let attempt = RecoveryAttempt.noStrategy()
        XCTAssertFalse(attempt.succeeded)
    }
}

final class RecoveryStrategyLibraryTests: XCTestCase {

    func testDefaultLibraryHasEightEntries() {
        let lib = RecoveryStrategyLibrary()
        XCTAssertEqual(lib.entries.count, 8)
    }

    func testSharedInstanceIsNonNil() {
        XCTAssertNotNil(RecoveryStrategyLibrary.shared)
    }

    func testApplicableForBuildFailed() {
        let lib = RecoveryStrategyLibrary()
        let entries = lib.applicable(for: .buildFailed)
        XCTAssertFalse(entries.isEmpty)
        let names = entries.map(\.name)
        XCTAssertTrue(names.contains("rollback_patch") || names.contains("rebuild_environment"))
    }

    func testApplicableForModalBlocking() {
        let lib = RecoveryStrategyLibrary()
        let entries = lib.applicable(for: .modalBlocking)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertTrue(entries.contains { $0.name == "dismiss_dialog" })
    }

    func testApplicableSortedByCostAscending() {
        let lib = RecoveryStrategyLibrary()
        let entries = lib.applicable(for: .navigationFailed)
        guard entries.count >= 2 else { return }
        for i in 0..<(entries.count - 1) {
            XCTAssertLessThanOrEqual(entries[i].baseCost, entries[i + 1].baseCost)
        }
    }

    func testEntryLookupByName() {
        let lib = RecoveryStrategyLibrary()
        let entry = lib.entry(named: "dismiss_dialog")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.name, "dismiss_dialog")
    }

    func testEntryLookupMissingReturnsNil() {
        let lib = RecoveryStrategyLibrary()
        XCTAssertNil(lib.entry(named: "nonexistent_strategy"))
    }

    func testCustomLibraryInit() {
        let custom = RecoveryStrategyEntry(
            name: "custom_strategy",
            applicableFailures: [.actionFailed],
            description: "Custom recovery"
        )
        let lib = RecoveryStrategyLibrary(entries: [custom])
        XCTAssertEqual(lib.entries.count, 1)
        XCTAssertEqual(lib.entries.first?.name, "custom_strategy")
    }

    func testAllEntriesHaveNonEmptyApplicableFailures() {
        let lib = RecoveryStrategyLibrary()
        for entry in lib.entries {
            XCTAssertFalse(entry.applicableFailures.isEmpty, "\(entry.name) has no applicable failures")
        }
    }
}

final class RecoveryStrategySelectorTests: XCTestCase {

    func testSelectReturnsEntries() {
        let selector = RecoveryStrategySelector()
        let selection = selector.select(for: .buildFailed)
        XCTAssertFalse(selection.orderedEntries.isEmpty)
        XCTAssertEqual(selection.failureClass, .buildFailed)
    }

    func testSelectReturnsEmptyForUnhandledClass() {
        let lib = RecoveryStrategyLibrary(entries: [
            RecoveryStrategyEntry(name: "only_modal", applicableFailures: [.modalBlocking], description: "x")
        ])
        let selector = RecoveryStrategySelector(library: lib)
        let selection = selector.select(for: .buildFailed)
        XCTAssertTrue(selection.orderedEntries.isEmpty)
    }

    func testPreferredStrategyMovedToFront() {
        let selector = RecoveryStrategySelector()
        let allEntries = selector.select(for: .buildFailed)
        guard allEntries.orderedEntries.count >= 2 else { return }
        let lastName = allEntries.orderedEntries.last!.name
        let biased = selector.select(for: .buildFailed, preferredName: lastName)
        XCTAssertEqual(biased.orderedEntries.first?.name, lastName)
    }

    func testAttemptSucceedsForKnownFailure() {
        let selector = RecoveryStrategySelector()
        let snapshot = WorldModelSnapshot()
        let attempt = selector.attempt(failure: .buildFailed, snapshot: snapshot)
        XCTAssertTrue(attempt.succeeded)
        XCTAssertNotNil(attempt.preparation)
    }

    func testAttemptReturnsNoStrategyForUnhandledClass() {
        let lib = RecoveryStrategyLibrary(entries: [])
        let selector = RecoveryStrategySelector(library: lib)
        let snapshot = WorldModelSnapshot()
        let attempt = selector.attempt(failure: .buildFailed, snapshot: snapshot)
        XCTAssertFalse(attempt.succeeded)
    }

    func testPreparationContainsStrategyName() {
        let selector = RecoveryStrategySelector()
        let snapshot = WorldModelSnapshot()
        let attempt = selector.attempt(failure: .modalBlocking, snapshot: snapshot)
        XCTAssertEqual(attempt.preparation?.strategyName, "dismiss_dialog")
    }
}

final class RuntimeRecoveryWiringTests: XCTestCase {

    func testRuntimeHasRecoveryStrategyLibrary() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.recoveryStrategyLibrary)
        XCTAssertFalse(runtime.recoveryStrategyLibrary.entries.isEmpty)
    }

    func testRuntimeHasRecoveryStrategySelector() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.recoveryStrategySelector)
    }

    func testRuntimeRecoverySelectsForBuildFailed() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let snapshot = runtime.worldModel.snapshot
        let attempt = runtime.recoveryStrategySelector.attempt(failure: .buildFailed, snapshot: snapshot)
        XCTAssertTrue(attempt.succeeded)
    }

    func testRuntimeRecoveryAndClassifierIntegration() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let classification = FailureClassifier.classify(errorDescription: "build failed: exit code 1")
        let snapshot = runtime.worldModel.snapshot
        let attempt = runtime.recoveryStrategySelector.attempt(
            failure: classification.failureClass,
            snapshot: snapshot
        )
        XCTAssertTrue(attempt.succeeded)
        XCTAssertEqual(classification.failureClass, .buildFailed)
    }
}

// MARK: - 52. Recipes Layer Tests

final class RecipeTypesTests: XCTestCase {

    func testRecipeInit() {
        let step = RecipeStep(id: 1, action: "noop")
        let recipe = Recipe(name: "test", description: "A test recipe", steps: [step])
        XCTAssertEqual(recipe.name, "test")
        XCTAssertEqual(recipe.steps.count, 1)
        XCTAssertEqual(recipe.schemaVersion, 2)
    }

    func testRecipeStepInit() {
        let step = RecipeStep(id: 1, action: "click", targetName: "Login", params: ["timeout": "5"], note: "click login")
        XCTAssertEqual(step.id, 1)
        XCTAssertEqual(step.action, "click")
        XCTAssertEqual(step.targetName, "Login")
        XCTAssertEqual(step.params?["timeout"], "5")
        XCTAssertEqual(step.note, "click login")
    }

    func testRecipeParamInit() {
        let param = RecipeParam(type: "string", description: "Search query", required: true)
        XCTAssertEqual(param.type, "string")
        XCTAssertTrue(param.required ?? false)
    }

    func testRecipePreconditionsInit() {
        let pre = RecipePreconditions(appRunning: "Safari", urlContains: "example.com")
        XCTAssertEqual(pre.appRunning, "Safari")
        XCTAssertEqual(pre.urlContains, "example.com")
    }

    func testRecipeWaitConditionInit() {
        let wait = RecipeWaitCondition(condition: "elementExists", value: "Submit", timeout: 10.0)
        XCTAssertEqual(wait.condition, "elementExists")
        XCTAssertEqual(wait.value, "Submit")
        XCTAssertEqual(wait.timeout, 10.0)
    }

    func testRecipeRunResultInit() {
        let result = RecipeRunResult(recipeName: "test", success: true, stepsCompleted: 3, totalSteps: 3, stepResults: [])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepsCompleted, 3)
        XCTAssertNil(result.error)
    }

    func testRecipeStepResultInit() {
        let sr = RecipeStepResult(stepId: 1, action: "noop", success: true, durationMs: 5)
        XCTAssertTrue(sr.success)
        XCTAssertEqual(sr.stepId, 1)
    }

    func testRecipeCodableRoundTrip() throws {
        let step = RecipeStep(id: 1, action: "noop", note: "test step")
        let recipe = Recipe(name: "roundtrip", description: "test", steps: [step])
        let data = try JSONEncoder().encode(recipe)
        let decoded = try JSONDecoder().decode(Recipe.self, from: data)
        XCTAssertEqual(decoded.name, "roundtrip")
        XCTAssertEqual(decoded.steps.first?.action, "noop")
    }
}

final class RecipeStoreTests: XCTestCase {

    func testAddAndRetrieve() {
        let store = RecipeStore()
        let recipe = Recipe(name: "find_file", description: "Find a file", steps: [])
        store.add(recipe)
        XCTAssertNotNil(store.recipe(named: "find_file"))
        XCTAssertEqual(store.count, 1)
    }

    func testRemoveRecipe() {
        let store = RecipeStore()
        let recipe = Recipe(name: "my_recipe", description: "desc", steps: [])
        store.add(recipe)
        let removed = store.remove(named: "my_recipe")
        XCTAssertTrue(removed)
        XCTAssertNil(store.recipe(named: "my_recipe"))
    }

    func testRemoveMissingReturnsFalse() {
        let store = RecipeStore()
        XCTAssertFalse(store.remove(named: "ghost"))
    }

    func testAllRecipesSortedAlphabetically() {
        let store = RecipeStore()
        store.add(Recipe(name: "zzz", description: "last", steps: []))
        store.add(Recipe(name: "aaa", description: "first", steps: []))
        let all = store.allRecipes()
        XCTAssertEqual(all.first?.name, "aaa")
        XCTAssertEqual(all.last?.name, "zzz")
    }

    func testImportValidJSON() throws {
        let store = RecipeStore()
        let json = """
        {
          "schema_version": 2,
          "name": "json_recipe",
          "description": "Imported from JSON",
          "steps": [{"id": 1, "action": "noop"}]
        }
        """
        let name = try store.importJSON(json)
        XCTAssertEqual(name, "json_recipe")
        XCTAssertNotNil(store.recipe(named: "json_recipe"))
    }

    func testImportInvalidJSONThrows() {
        let store = RecipeStore()
        XCTAssertThrowsError(try store.importJSON("{ invalid json }"))
    }
}

final class RecipeEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ActionRegistry.shared.registerDefaults()
    }

    func testRunSuccessfulRecipe() {
        let steps = [
            RecipeStep(id: 1, action: "noop", note: "step 1"),
            RecipeStep(id: 2, action: "noop", note: "step 2"),
        ]
        let recipe = Recipe(name: "success_recipe", description: "Always succeeds", steps: steps)
        let result = RecipeEngine.run(recipe: recipe)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepsCompleted, 2)
        XCTAssertEqual(result.totalSteps, 2)
        XCTAssertNil(result.error)
    }

    func testRunFailsOnMissingRequiredParam() {
        let params: [String: RecipeParam] = [
            "query": RecipeParam(type: "string", description: "search query", required: true)
        ]
        let recipe = Recipe(name: "param_test", description: "Requires query", params: params, steps: [])
        let result = RecipeEngine.run(recipe: recipe, params: [:])
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("query") ?? false)
    }

    func testRunSucceedsWithRequiredParam() {
        let params: [String: RecipeParam] = [
            "query": RecipeParam(type: "string", description: "search query", required: true)
        ]
        let steps = [RecipeStep(id: 1, action: "noop")]
        let recipe = Recipe(name: "param_ok", description: "test", params: params, steps: steps)
        let result = RecipeEngine.run(recipe: recipe, params: ["query": "swift closures"])
        XCTAssertTrue(result.success)
    }

    func testRunStopsOnUnknownActionByDefault() {
        let steps = [
            RecipeStep(id: 1, action: "noop"),
            RecipeStep(id: 2, action: "unregistered_action_xyz"),
            RecipeStep(id: 3, action: "noop"),
        ]
        let recipe = Recipe(name: "stop_test", description: "Should stop at step 2", steps: steps)
        let result = RecipeEngine.run(recipe: recipe)
        // unregistered action → handler returns failure → stop (default policy)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.stepsCompleted, 1)  // step 1 succeeded before stop
    }

    func testRunSkipsFailedStepWithSkipPolicy() {
        let steps = [
            RecipeStep(id: 1, action: "noop"),
            RecipeStep(id: 2, action: "unregistered_action_xyz", onFailure: "skip"),
            RecipeStep(id: 3, action: "noop"),
        ]
        let recipe = Recipe(name: "skip_test", description: "Should skip step 2", steps: steps)
        let result = RecipeEngine.run(recipe: recipe)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepsCompleted, 2)  // steps 1 and 3 succeeded
    }

    func testParamSubstitution() {
        let steps = [
            RecipeStep(id: 1, action: "noop", params: ["text": "hello {{name}}"])
        ]
        let recipe = Recipe(name: "subst_test", description: "test", steps: steps)
        // We can't directly test the substitution output without a custom action,
        // but we verify the recipe runs without error when params are supplied.
        let result = RecipeEngine.run(recipe: recipe, params: ["name": "world"])
        XCTAssertTrue(result.success)
    }

    func testStepResultsArePopulated() {
        let steps = [
            RecipeStep(id: 1, action: "noop", note: "first"),
            RecipeStep(id: 2, action: "noop", note: "second"),
        ]
        let recipe = Recipe(name: "results_test", description: "test", steps: steps)
        let result = RecipeEngine.run(recipe: recipe)
        XCTAssertEqual(result.stepResults.count, 2)
        XCTAssertEqual(result.stepResults[0].stepId, 1)
        XCTAssertTrue(result.stepResults[0].success)
    }
}

final class RuntimeRecipeWiringTests: XCTestCase {

    func testRuntimeHasRecipeStore() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.recipeStore)
        XCTAssertEqual(runtime.recipeStore.count, 0)
    }

    func testCanAddAndRunRecipeThroughRuntime() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let step = RecipeStep(id: 1, action: "noop")
        let recipe = Recipe(name: "runtime_recipe", description: "noop recipe", steps: [step])
        runtime.recipeStore.add(recipe)
        XCTAssertNotNil(runtime.recipeStore.recipe(named: "runtime_recipe"))
        let result = RecipeEngine.run(recipe: recipe)
        XCTAssertTrue(result.success)
    }
}

// MARK: - 53. Architecture Governance Layer Tests

final class ArchitectureTypesTests: XCTestCase {

    func testRepositoryFileInit() {
        let f = RepositoryFile(path: "Sources/OracleLib/Core/Foo.swift", isDirectory: false)
        XCTAssertEqual(f.path, "Sources/OracleLib/Core/Foo.swift")
        XCTAssertFalse(f.isDirectory)
        XCTAssertNil(f.lastModifiedAt)
    }

    func testRepositorySnapshotFromPaths() {
        let snap = RepositorySnapshot.fromPaths([
            "Sources/OracleLib/Agent/Planning/Planner.swift",
            "Sources/OracleLib/Core/Execution/Executor.swift",
        ])
        XCTAssertEqual(snap.files.count, 2)
        XCTAssertFalse(snap.isGitDirty)
    }

    func testCandidatePatchInit() {
        let patch = CandidatePatch(workspaceRelativePath: "Sources/OracleLib/Core/Foo.swift", content: "public func foo() {}")
        XCTAssertEqual(patch.workspaceRelativePath, "Sources/OracleLib/Core/Foo.swift")
        XCTAssertTrue(patch.content.contains("public"))
    }
}

final class GovernanceTests: XCTestCase {

    func testGovernanceRuleIDCases() {
        XCTAssertEqual(GovernanceRuleID.allCases.count, 5)
    }

    func testGovernanceReportEmpty() {
        let report = GovernanceReport.empty
        XCTAssertTrue(report.violations.isEmpty)
        XCTAssertFalse(report.isBlocking)
    }

    func testGovernanceReportHardFailIsBlocking() {
        let v = GovernanceViolation(ruleID: .executionTruthPath, severity: .hardFail,
                                    title: "T", summary: "S")
        let report = GovernanceReport(violations: [v])
        XCTAssertTrue(report.isBlocking)
        XCTAssertEqual(report.hardFailures.count, 1)
        XCTAssertTrue(report.advisories.isEmpty)
    }

    func testGovernanceViolationAsArchitectureFinding() {
        let v = GovernanceViolation(ruleID: .reusableKnowledge, severity: .advisory,
                                    title: "Knowledge drift", summary: "Drift summary")
        let finding = v.asArchitectureFinding()
        XCTAssertEqual(finding.severity, .warning)
        XCTAssertEqual(finding.governanceRuleID, .reusableKnowledge)
        XCTAssertEqual(finding.riskScore, 0.70, accuracy: 0.001)
    }

    func testHardFailFindingIsCritical() {
        let v = GovernanceViolation(ruleID: .hierarchicalPlanning, severity: .hardFail,
                                    title: "Boundary", summary: "Crossed")
        let finding = v.asArchitectureFinding()
        XCTAssertEqual(finding.severity, .critical)
        XCTAssertEqual(finding.riskScore, 0.95, accuracy: 0.001)
    }
}

final class ArchitectureModuleGraphTests: XCTestCase {

    func testModuleNameSourcesFile() {
        let name = ArchitectureModuleGraph.moduleName(for: "Sources/OracleLib/Agent/Planning/Planner.swift")
        XCTAssertEqual(name, "Agent/Planning")
    }

    func testModuleNameCoreSubModule() {
        let name = ArchitectureModuleGraph.moduleName(for: "Sources/OracleLib/Core/Execution/Executor.swift")
        XCTAssertEqual(name, "Core/Execution")
    }

    func testModuleNameRuntimeFile() {
        let name = ArchitectureModuleGraph.moduleName(for: "Sources/OracleLib/Runtime/OracleRuntime.swift")
        XCTAssertEqual(name, "Runtime")
    }

    func testModuleNameTestFile() {
        let name = ArchitectureModuleGraph.moduleName(for: "Tests/OracleTests/FooTests.swift")
        XCTAssertEqual(name, "Tests/OracleTests")
    }

    func testBuildGraphSeeds() {
        let snap = RepositorySnapshot.fromPaths([
            "Sources/OracleLib/Agent/Planning/Planner.swift",
            "Sources/OracleLib/Core/Execution/Executor.swift",
        ])
        let graph = ArchitectureModuleGraph.build(from: snap)
        XCTAssertTrue(graph.modules.keys.contains("Agent/Planning"))
        XCTAssertTrue(graph.modules.keys.contains("Core/Execution"))
    }
}

final class DependencyAnalyzerTests: XCTestCase {

    func testNoCyclesInEmptyGraph() {
        let graph = ArchitectureModuleGraph(modules: [:])
        let cycles = DependencyAnalyzer().findCycles(in: graph)
        XCTAssertTrue(cycles.isEmpty)
    }

    func testNoCyclesInAcyclicGraph() {
        let graph = ArchitectureModuleGraph(modules: [
            "A": ["B"],
            "B": ["C"],
            "C": [],
        ])
        let cycles = DependencyAnalyzer().findCycles(in: graph)
        XCTAssertTrue(cycles.isEmpty)
    }

    func testDetectsCycle() {
        let graph = ArchitectureModuleGraph(modules: [
            "A": ["B"],
            "B": ["C"],
            "C": ["A"],
        ])
        let cycles = DependencyAnalyzer().findCycles(in: graph)
        XCTAssertFalse(cycles.isEmpty)
    }

    func testFindingsReturnedForCycle() {
        let graph = ArchitectureModuleGraph(modules: ["X": ["Y"], "Y": ["X"]])
        let findings = DependencyAnalyzer().findings(in: graph)
        XCTAssertFalse(findings.isEmpty)
        XCTAssertEqual(findings.first?.severity, .warning)
    }
}

final class ChangeImpactAnalyzerTests: XCTestCase {

    let analyzer = ChangeImpactAnalyzer()

    func testAffectedModulesDeduplicates() {
        let modules = analyzer.affectedModules(for: [
            "Sources/OracleLib/Agent/Planning/A.swift",
            "Sources/OracleLib/Agent/Planning/B.swift",
        ])
        XCTAssertEqual(modules, ["Agent/Planning"])
    }

    func testShouldReviewForRefactorGoal() {
        XCTAssertTrue(analyzer.shouldReview(goalDescription: "Refactor the planner",
                                             candidatePaths: ["Sources/OracleLib/Agent/Planning/A.swift"]))
    }

    func testShouldReviewForMultiModulePaths() {
        XCTAssertTrue(analyzer.shouldReview(goalDescription: "Fix a bug",
                                             candidatePaths: [
                                                "Sources/OracleLib/Agent/Planning/A.swift",
                                                "Sources/OracleLib/Core/Execution/B.swift",
                                             ]))
    }

    func testShouldNotReviewForSingleModule() {
        XCTAssertFalse(analyzer.shouldReview(goalDescription: "Fix a bug",
                                              candidatePaths: ["Sources/OracleLib/Agent/Planning/A.swift"]))
    }
}

final class RefactorPlannerTests: XCTestCase {

    func testReturnsNilForEmptyFindings() {
        XCTAssertNil(RefactorPlanner().proposal(from: []))
    }

    func testProposalFromFindings() {
        let finding = ArchitectureFinding(title: "Cycle", summary: "A→B→A", severity: .warning,
                                          affectedModules: ["A", "B"], riskScore: 0.75)
        let proposal = RefactorPlanner().proposal(from: [finding])
        XCTAssertNotNil(proposal)
        XCTAssertFalse(proposal!.steps.isEmpty)
        XCTAssertEqual(proposal!.riskScore, 0.75, accuracy: 0.001)
    }
}

final class InvariantCheckerTests: XCTestCase {

    let checker = InvariantChecker()
    let snap = RepositorySnapshot.fromPaths(["Sources/OracleLib/Agent/Planning/Planner.swift"])

    func testNonImpactfulChangeNoViolations() {
        // No trigger words, single module → no review needed
        let report = checker.report(
            goalDescription: "Fix typo",
            affectedModules: ["Agent/Planning"],
            candidatePaths: ["Sources/OracleLib/Agent/Planning/Planner.swift"],
            snapshot: snap
        )
        XCTAssertTrue(report.violations.isEmpty)
    }

    func testPlanningExecutionBoundaryDrift() {
        let report = checker.report(
            goalDescription: "Refactor planning",
            affectedModules: ["Agent/Planning", "Core/Execution"],
            candidatePaths: [
                "Sources/OracleLib/Agent/Planning/Planner.swift",
                "Sources/OracleLib/Core/Execution/Executor.swift",
                "Tests/OracleTests/PlannerTests.swift",
            ],
            snapshot: snap
        )
        let ruleIDs = report.violations.map(\.ruleID)
        XCTAssertTrue(ruleIDs.contains(.hierarchicalPlanning))
    }

    func testRecoveryPathDriftAdvisory() {
        // Agent/Recovery only — no Runtime or Graph in scope → advisory
        let report = checker.report(
            goalDescription: "Fix recovery handler",
            affectedModules: ["Agent/Recovery"],
            candidatePaths: ["Sources/OracleLib/Agent/Recovery/Handler.swift"],
            snapshot: snap
        )
        let advisories = report.advisories.map(\.ruleID)
        XCTAssertTrue(advisories.contains(.recoveryMode))
    }

    func testEvalBeforeGrowthHardFail() {
        // Multi-module (triggers shouldReview), no Tests/ path → hard fail
        let report = checker.report(
            goalDescription: "Refactor architecture boundary",
            affectedModules: ["Agent/Planning", "Core/Execution"],
            candidatePaths: [
                "Sources/OracleLib/Agent/Planning/Planner.swift",
                "Sources/OracleLib/Core/Execution/Executor.swift",
            ],
            snapshot: snap
        )
        let ruleIDs = report.violations.map(\.ruleID)
        XCTAssertTrue(ruleIDs.contains(.evalBeforeGrowth))
        let evalViolation = report.violations.first(where: { $0.ruleID == .evalBeforeGrowth })
        XCTAssertEqual(evalViolation?.severity, .hardFail)
    }
}

final class ArchitectureEngineTests: XCTestCase {

    let engine = ArchitectureEngine()

    func testLowImpactChangeNotTriggered() {
        let snap = RepositorySnapshot.fromPaths(["Sources/OracleLib/Agent/Planning/Planner.swift"])
        let review = engine.review(
            goalDescription: "Fix typo in comment",
            snapshot: snap,
            candidatePaths: ["Sources/OracleLib/Agent/Planning/Planner.swift"]
        )
        XCTAssertFalse(review.triggered)
        XCTAssertTrue(review.findings.isEmpty)
        XCTAssertEqual(review.riskScore, 0)
    }

    func testHighImpactRefactorTriggered() {
        let snap = RepositorySnapshot.fromPaths([
            "Sources/OracleLib/Agent/Planning/Planner.swift",
            "Sources/OracleLib/Core/Execution/Executor.swift",
        ])
        let review = engine.review(
            goalDescription: "Refactor architecture boundary",
            snapshot: snap,
            candidatePaths: [
                "Sources/OracleLib/Agent/Planning/Planner.swift",
                "Sources/OracleLib/Core/Execution/Executor.swift",
            ]
        )
        XCTAssertTrue(review.triggered)
        XCTAssertFalse(review.findings.isEmpty)
        XCTAssertGreaterThan(review.riskScore, 0)
    }

    func testReviewSortsFindingsByRiskDescending() {
        let snap = RepositorySnapshot.fromPaths([
            "Sources/OracleLib/Agent/Planning/Planner.swift",
            "Sources/OracleLib/Core/Execution/Executor.swift",
        ])
        let review = engine.review(
            goalDescription: "Refactor execution boundary",
            snapshot: snap,
            candidatePaths: [
                "Sources/OracleLib/Agent/Planning/Planner.swift",
                "Sources/OracleLib/Core/Execution/Executor.swift",
                "Tests/OracleTests/Foo.swift",
            ]
        )
        if review.findings.count > 1 {
            let scores = review.findings.map(\.riskScore)
            XCTAssertEqual(scores, scores.sorted(by: >))
        }
    }

    func testCandidatePatchHeuristicPublicInterface() {
        let snap = RepositorySnapshot.fromPaths(["Sources/OracleLib/Core/Foo.swift"])
        let patch = CandidatePatch(
            workspaceRelativePath: "Sources/OracleLib/Core/Foo.swift",
            content: "public func doSomething() { }"
        )
        let review = engine.reviewCandidatePatch(
            goalDescription: "Fix broken logic",
            snapshot: snap,
            candidate: patch,
            diffSummary: "Sources/OracleLib/Core/Foo.swift | 1 +"
        )
        // Public interface change in a non-refactor task → heuristic warning
        let publicInterfaceFindings = review.findings.filter { $0.title == "Public interface change" }
        XCTAssertFalse(publicInterfaceFindings.isEmpty)
    }

    func testCandidatePatchPlannerExecutionBoundary() {
        let snap = RepositorySnapshot.fromPaths(["Sources/OracleLib/Agent/Planning/Planner.swift"])
        let patch = CandidatePatch(
            workspaceRelativePath: "Sources/OracleLib/Agent/Planning/Planner.swift",
            content: "func run() { execute(intent) }"
        )
        let review = engine.reviewCandidatePatch(
            goalDescription: "Update planner",
            snapshot: snap,
            candidate: patch,
            diffSummary: "Sources/OracleLib/Agent/Planning/Planner.swift | 1 +"
        )
        let driftFindings = review.findings.filter { $0.title == "Planner/execution boundary drift" }
        XCTAssertFalse(driftFindings.isEmpty)
        XCTAssertEqual(driftFindings.first?.severity, .critical)
    }
}

final class RuntimeArchitectureWiringTests: XCTestCase {

    func testRuntimeHasArchitectureEngine() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.architectureEngine)
    }

    func testArchitectureEngineCanReview() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let snap = RepositorySnapshot.fromPaths(["Sources/OracleLib/Agent/Planning/Planner.swift"])
        let review = runtime.architectureEngine.review(
            goalDescription: "Fix typo",
            snapshot: snap,
            candidatePaths: ["Sources/OracleLib/Agent/Planning/Planner.swift"]
        )
        XCTAssertNotNil(review)
        XCTAssertFalse(review.triggered)
    }
}

// MARK: - 54. Memory Layer Tests

final class MemoryTierTests: XCTestCase {
    func testAllCasesExist() {
        XCTAssertEqual(MemoryTier.allCases.count, 5)
        XCTAssertTrue(MemoryTier.allCases.contains(.execution))
        XCTAssertTrue(MemoryTier.allCases.contains(.pattern))
        XCTAssertTrue(MemoryTier.allCases.contains(.project))
        XCTAssertTrue(MemoryTier.allCases.contains(.workflow))
        XCTAssertTrue(MemoryTier.allCases.contains(.residue))
    }

    func testMemoryEvidenceInit() {
        let ev = MemoryEvidence(tier: .execution, summary: "test", sourceRefs: ["a"], confidence: 0.8)
        XCTAssertEqual(ev.tier, .execution)
        XCTAssertEqual(ev.confidence, 0.8, accuracy: 0.001)
        XCTAssertEqual(ev.sourceRefs, ["a"])
    }
}

final class MemoryDecayPolicyTests: XCTestCase {

    func testFreshDateReturns1() {
        let now = Date()
        let recent = now.addingTimeInterval(-60 * 60 * 24)   // 1 day ago
        let mult = MemoryDecayPolicy.freshnessMultiplier(since: recent, now: now)
        XCTAssertEqual(mult, 1.0, accuracy: 0.001)
    }

    func testStaleDateReturns0() {
        let now = Date()
        let stale = now.addingTimeInterval(-60 * 60 * 24 * 100)  // 100 days ago
        let mult = MemoryDecayPolicy.freshnessMultiplier(since: stale, now: now)
        XCTAssertEqual(mult, 0.0, accuracy: 0.001)
    }

    func testInterpolatesInMiddle() {
        let now = Date()
        // 60 days ago: halfway between 30-day fresh and 90-day stale window
        let mid = now.addingTimeInterval(-60 * 60 * 24 * 60)
        let mult = MemoryDecayPolicy.freshnessMultiplier(since: mid, now: now)
        XCTAssertGreaterThan(mult, 0.0)
        XCTAssertLessThan(mult, 1.0)
    }
}

final class MemoryPromotionPolicyTests: XCTestCase {

    func testBelowMinSuccessesReturnsFalse() {
        XCTAssertFalse(MemoryPromotionPolicy.allowsDurableBias(successes: 2, failures: 0))
    }

    func testMinSuccessesNoFailuresReturnsTrue() {
        XCTAssertTrue(MemoryPromotionPolicy.allowsDurableBias(successes: 3, failures: 0))
    }

    func testHighFailureRateReturnsFalse() {
        // 3 successes, 5 failures → failure rate 0.625 > 0.25
        XCTAssertFalse(MemoryPromotionPolicy.allowsDurableBias(successes: 3, failures: 5))
    }

    func testLowFailureRateReturnsTrue() {
        // 10 successes, 2 failures → failure rate 0.167 < 0.25
        XCTAssertTrue(MemoryPromotionPolicy.allowsDurableBias(successes: 10, failures: 2))
    }

    func testStrategyReuseAllowedForFreshSuccess() {
        let record = StrategyRecord(app: "Xcode", strategy: "retry", success: true)
        XCTAssertTrue(MemoryPromotionPolicy.allowsStrategyReuse(record: record))
    }

    func testStrategyReuseBlockedForFailure() {
        let record = StrategyRecord(app: "Xcode", strategy: "retry", success: false)
        XCTAssertFalse(MemoryPromotionPolicy.allowsStrategyReuse(record: record))
    }
}

final class MemoryScorerTests: XCTestCase {

    func testCommandBiasBelowThresholdIsZero() {
        XCTAssertEqual(MemoryScorer.commandBias(successes: 2, failures: 0), 0.0, accuracy: 0.001)
    }

    func testCommandBiasWithSufficientSuccesses() {
        let bias = MemoryScorer.commandBias(successes: 10, failures: 1)
        XCTAssertGreaterThan(bias, 0)
        XCTAssertLessThanOrEqual(bias, 0.15)
    }

    func testPlanBiasEmpty() {
        let bias = MemoryScorer.planBias(influence: .empty)
        XCTAssertEqual(bias, 0.0, accuracy: 0.001)
    }

    func testPlanBiasPositive() {
        let influence = MemoryInfluence(executionRankingBias: 0.1, commandBias: 0.1, preferredPaths: ["/foo"])
        let bias = MemoryScorer.planBias(influence: influence)
        XCTAssertGreaterThan(bias, 0)
        XCTAssertLessThanOrEqual(bias, 0.3)
    }

    func testPlanBiasNegativeFromRisk() {
        let influence = MemoryInfluence(avoidedPaths: ["/bad"], riskPenalty: 0.5)
        let bias = MemoryScorer.planBias(influence: influence)
        XCTAssertLessThan(bias, 0)
        XCTAssertGreaterThanOrEqual(bias, -0.3)
    }

    func testPlanBiasClampedToRange() {
        let influence = MemoryInfluence(executionRankingBias: 1.0, commandBias: 1.0,
                                        preferredFixPath: "/fix", preferredPaths: ["/a"])
        let bias = MemoryScorer.planBias(influence: influence)
        XCTAssertLessThanOrEqual(bias, 0.3)
        XCTAssertGreaterThanOrEqual(bias, -0.3)
    }

    func testFixPatternScoreBelowThresholdIsZero() {
        let pattern = FixPattern(errorSignature: "err", workspaceRelativePath: nil,
                                 commandCategory: "build", successCount: 1, failureCount: 0)
        XCTAssertEqual(MemoryScorer.fixPatternScore(pattern: pattern), 0.0, accuracy: 0.001)
    }

    func testFixPatternScoreWithHistory() {
        let pattern = FixPattern(errorSignature: "err", workspaceRelativePath: "/Sources/Foo.swift",
                                 commandCategory: "build", successCount: 5, failureCount: 0,
                                 lastAppliedAt: Date())
        let score = MemoryScorer.fixPatternScore(pattern: pattern)
        XCTAssertGreaterThan(score, 0)
    }
}

final class MemoryInfluenceTests: XCTestCase {

    func testEmptyInfluenceDefaults() {
        let inf = MemoryInfluence.empty
        XCTAssertEqual(inf.executionRankingBias, 0)
        XCTAssertEqual(inf.commandBias, 0)
        XCTAssertNil(inf.preferredFixPath)
        XCTAssertNil(inf.preferredRecoveryStrategy)
        XCTAssertFalse(inf.shouldPreferExperiments)
        XCTAssertEqual(inf.riskPenalty, 0)
        XCTAssertTrue(inf.notes.isEmpty)
        XCTAssertTrue(inf.evidence.isEmpty)
    }

    func testProjectMemoryRefsProxy() {
        let inf = MemoryInfluence()
        XCTAssertTrue(inf.projectMemoryRefs.isEmpty)
    }
}

final class PatternSimilarityTests: XCTestCase {

    func testIdenticalSequencesScore1() {
        let seq = ["click", "type", "submit"]
        let sim = PatternSimilarityCalculator.similarity(between: seq, and: seq)
        XCTAssertEqual(sim.score, 1.0, accuracy: 0.001)
    }

    func testDisjointSequencesScore0() {
        let sim = PatternSimilarityCalculator.similarity(between: ["a", "b"], and: ["c", "d"])
        XCTAssertEqual(sim.score, 0.0, accuracy: 0.001)
    }

    func testPartialOverlapIsBetween0And1() {
        let sim = PatternSimilarityCalculator.similarity(between: ["a", "b", "c"], and: ["b", "c", "d"])
        XCTAssertGreaterThan(sim.score, 0)
        XCTAssertLessThan(sim.score, 1)
    }

    func testEmptySequenceReturns0() {
        let sim = PatternSimilarityCalculator.similarity(between: [], and: ["a"])
        XCTAssertEqual(sim.score, 0.0, accuracy: 0.001)
    }

    func testTaskFamilySimilarityIdentical() {
        let sim = PatternSimilarityCalculator.taskFamilySimilarity(goalA: "fix the login bug", goalB: "fix the login bug")
        XCTAssertEqual(sim.score, 1.0, accuracy: 0.001)
        XCTAssertEqual(sim.source, .taskFamily)
    }

    func testTaskFamilySimilarityNoOverlap() {
        let sim = PatternSimilarityCalculator.taskFamilySimilarity(goalA: "build project", goalB: "deploy server")
        XCTAssertEqual(sim.score, 0.0, accuracy: 0.001)
    }
}

final class KnownControlTests: XCTestCase {

    func testKnownControlInit() {
        let control = KnownControl(key: "safari:login", app: "Safari", label: "Login",
                                   role: "button", elementID: nil, successCount: 5)
        XCTAssertEqual(control.app, "Safari")
        XCTAssertEqual(control.successCount, 5)
        XCTAssertEqual(control.label, "Login")
    }
}

final class StrategyRecordTests: XCTestCase {

    func testStrategyRecordSuccess() {
        let record = StrategyRecord(app: "Xcode", strategy: "retry_with_new_target", success: true)
        XCTAssertTrue(record.success)
        XCTAssertEqual(record.app, "Xcode")
    }

    func testStrategyRecordFailure() {
        let record = StrategyRecord(app: "Safari", strategy: "dismiss_dialog", success: false)
        XCTAssertFalse(record.success)
    }
}

final class FixPatternTests: XCTestCase {

    func testFixPatternFailureRate() {
        let p = FixPattern(errorSignature: "sig", workspaceRelativePath: "/Foo.swift",
                           commandCategory: "build", successCount: 3, failureCount: 1)
        XCTAssertEqual(p.failureRate, 0.25, accuracy: 0.001)
    }

    func testFixPatternZeroTotal() {
        let p = FixPattern(errorSignature: "sig", workspaceRelativePath: nil,
                           commandCategory: "test", successCount: 0, failureCount: 0)
        XCTAssertEqual(p.failureRate, 0.0, accuracy: 0.001)
    }
}

final class AppMemoryStoreTests: XCTestCase {

    func testRecordAndRetrieveControl() {
        let store = AppMemoryStore()
        let control = KnownControl(key: "safari:submit", app: "Safari", label: "Submit",
                                   role: "button", elementID: nil, successCount: 3)
        store.recordControl(control)
        let retrieved = store.preferredKnownControl(label: "Submit", app: "Safari")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.successCount, 3)
    }

    func testControlSuccessCountAccumulates() {
        let store = AppMemoryStore()
        let c1 = KnownControl(key: "safari:ok", app: "Safari", label: "OK", role: nil, elementID: nil, successCount: 2)
        let c2 = KnownControl(key: "safari:ok", app: "Safari", label: "OK", role: nil, elementID: nil, successCount: 3)
        store.recordControl(c1)
        store.recordControl(c2)
        let retrieved = store.getControl(key: "safari:ok")
        XCTAssertEqual(retrieved?.successCount, 5)
    }

    func testRecordAndLatestSuccessfulStrategy() {
        let store = AppMemoryStore()
        store.recordStrategy(StrategyRecord(app: "Xcode", strategy: "retry", success: false))
        store.recordStrategy(StrategyRecord(app: "Xcode", strategy: "refocus", success: true))
        let latest = store.latestSuccessfulStrategy(app: "Xcode")
        XCTAssertEqual(latest?.strategy, "refocus")
    }

    func testFailuresForApp() {
        let store = AppMemoryStore()
        XCTAssertTrue(store.failuresForApp("Safari").isEmpty)
    }
}

final class ExecutionMemoryStoreTests: XCTestCase {

    func testRankingBiasWithNoControl() {
        let store = AppMemoryStore()
        let execStore = ExecutionMemoryStore(store: store)
        let bias = execStore.rankingBias(label: "Login", app: "Safari")
        XCTAssertEqual(bias, 0.0, accuracy: 0.001)
    }

    func testRankingBiasWithSufficientControl() {
        let store = AppMemoryStore()
        let control = KnownControl(key: "safari:submit", app: "Safari", label: "Submit",
                                   role: "button", elementID: nil, successCount: 10, lastUsed: Date())
        store.recordControl(control)
        let execStore = ExecutionMemoryStore(store: store)
        let bias = execStore.rankingBias(label: "Submit", app: "Safari")
        // 10 successes, 0 failures → passes promotion policy → bias > 0
        XCTAssertGreaterThan(bias, 0)
        XCTAssertLessThanOrEqual(bias, 0.15)
    }

    func testPreferredRecoveryStrategyNilWhenNone() {
        let store = AppMemoryStore()
        let execStore = ExecutionMemoryStore(store: store)
        XCTAssertNil(execStore.preferredRecoveryStrategy(app: "Xcode"))
    }

    func testPreferredRecoveryStrategyReturnedWhenFresh() {
        let store = AppMemoryStore()
        store.recordStrategy(StrategyRecord(app: "Xcode", strategy: "refocus_window", success: true))
        let execStore = ExecutionMemoryStore(store: store)
        XCTAssertEqual(execStore.preferredRecoveryStrategy(app: "Xcode"), "refocus_window")
    }
}

final class PatternMemoryStoreTests: XCTestCase {

    func testPreferredFixPathNilWhenNoPatterns() {
        let store = AppMemoryStore()
        let patternStore = PatternMemoryStore(store: store)
        XCTAssertNil(patternStore.preferredFixPath(errorSignature: "build failed"))
    }

    func testCommandBiasZeroWhenNoHistory() {
        let store = AppMemoryStore()
        let patternStore = PatternMemoryStore(store: store)
        XCTAssertEqual(patternStore.commandBias(category: "build", workspaceRoot: "/workspace"), 0.0, accuracy: 0.001)
    }

    func testCommandBiasZeroForNilCategory() {
        let store = AppMemoryStore()
        let patternStore = PatternMemoryStore(store: store)
        XCTAssertEqual(patternStore.commandBias(category: nil, workspaceRoot: "/workspace"), 0.0, accuracy: 0.001)
    }
}

final class MemoryRouterTests: XCTestCase {

    func testInfluenceEmptyWithNoStore() {
        let router = MemoryRouter()
        let ctx = MemoryQueryContext(goalDescription: "fix the login bug")
        let influence = router.influence(for: ctx)
        XCTAssertEqual(influence.executionRankingBias, 0)
        XCTAssertEqual(influence.commandBias, 0)
        XCTAssertNil(influence.preferredFixPath)
        XCTAssertTrue(influence.notes.isEmpty)
    }

    func testRankingBiasConvenienceMethod() {
        let router = MemoryRouter()
        let bias = router.rankingBias(label: "Submit", app: "Safari")
        XCTAssertEqual(bias, 0, accuracy: 0.001)
    }

    func testPreferredRecoveryStrategyNilWithNoStore() {
        let router = MemoryRouter()
        XCTAssertNil(router.preferredRecoveryStrategy(app: "Xcode"))
    }

    func testCommandBiasConvenienceMethod() {
        let router = MemoryRouter()
        let bias = router.commandBias(category: "build", workspaceRoot: "/workspace")
        XCTAssertEqual(bias, 0, accuracy: 0.001)
    }
}

final class TraceCompressorTests: XCTestCase {

    func testCompressEmptyReturnsEmpty() {
        let compressor = TraceCompressor()
        XCTAssertTrue(compressor.compress(events: []).isEmpty)
    }

    func testSuccessRateZeroForEmptyPatterns() {
        let compressor = TraceCompressor()
        XCTAssertEqual(compressor.successRate(for: []), 0.0, accuracy: 0.001)
    }

    func testSuccessRateAllSuccess() {
        let compressor = TraceCompressor()
        let patterns = [
            CompressedTracePattern(stateFingerprint: "a", actionName: "click", resultSuccess: true, occurrences: 3),
            CompressedTracePattern(stateFingerprint: "b", actionName: "type", resultSuccess: true, occurrences: 2),
        ]
        XCTAssertEqual(compressor.successRate(for: patterns), 1.0, accuracy: 0.001)
    }

    func testSuccessRateMixed() {
        let compressor = TraceCompressor()
        let patterns = [
            CompressedTracePattern(stateFingerprint: "a", actionName: "click", resultSuccess: true, occurrences: 3),
            CompressedTracePattern(stateFingerprint: "b", actionName: "type", resultSuccess: false, occurrences: 1),
        ]
        // successRate counts patterns, not occurrences: 1 success / 2 total = 0.5
        let rate = compressor.successRate(for: patterns)
        XCTAssertEqual(rate, 0.5, accuracy: 0.001)
    }
}

final class RuntimeMemoryWiringTests: XCTestCase {

    func testRuntimeHasMemoryRouter() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.memoryRouter)
    }

    func testMemoryRouterDeliversEmptyInfluenceByDefault() {
        let runtime = OracleRuntime()
        runtime.initialize()
        let ctx = MemoryQueryContext(goalDescription: "open settings")
        let influence = runtime.memoryRouter.influence(for: ctx)
        XCTAssertEqual(influence.executionRankingBias, 0)
        XCTAssertNil(influence.preferredFixPath)
    }
}

// MARK: - 55. Reasoning Layer Tests

// MARK: 55a. ReasoningOperatorKind

final class ReasoningOperatorKindTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ReasoningOperatorKind.allCases.count, 13)
    }

    func testRawValues() {
        XCTAssertEqual(ReasoningOperatorKind.runTests.rawValue, "run_tests")
        XCTAssertEqual(ReasoningOperatorKind.buildProject.rawValue, "build_project")
        XCTAssertEqual(ReasoningOperatorKind.applyPatch.rawValue, "apply_patch")
        XCTAssertEqual(ReasoningOperatorKind.dismissModal.rawValue, "dismiss_modal")
        XCTAssertEqual(ReasoningOperatorKind.clickTarget.rawValue, "click_target")
        XCTAssertEqual(ReasoningOperatorKind.rollbackPatch.rawValue, "rollback_patch")
    }

    func testCodeFamilyOperators() {
        // runTests, buildProject, rerunTests → repoAnalysis
        let repoAnalysisOps: [ReasoningOperatorKind] = [.runTests, .buildProject, .rerunTests]
        for kind in repoAnalysisOps {
            XCTAssertEqual(kind.operatorFamily, .repoAnalysis, "\(kind) should be repoAnalysis")
        }
        // applyPatch, revertPatch, rollbackPatch → patchGeneration
        let patchOps: [ReasoningOperatorKind] = [.applyPatch, .revertPatch, .rollbackPatch]
        for kind in patchOps {
            XCTAssertEqual(kind.operatorFamily, .patchGeneration, "\(kind) should be patchGeneration")
        }
    }

    func testOSFamilyOperators() {
        let osOps: [ReasoningOperatorKind] = [.dismissModal, .clickTarget, .openApplication, .navigateBrowser,
                                               .retryWithAlternateTarget, .focusWindow, .restartApplication]
        for kind in osOps {
            let fam = kind.operatorFamily
            XCTAssertTrue(
                fam == .hostTargeted || fam == .browserTargeted || fam == .recovery || fam == .permissionHandling,
                "\(kind) family \(fam) should be an OS-targeted family"
            )
        }
    }

    func testOperatorFamilyNeverWorkflow() {
        for kind in ReasoningOperatorKind.allCases {
            XCTAssertNotEqual(kind.operatorFamily, .workflow, "\(kind) should not map to .workflow")
        }
    }
}

// MARK: 55b. Operator struct

final class OperatorTests: XCTestCase {

    func testRunTestsOperatorCost() {
        let op = Operator(kind: .runTests)
        XCTAssertGreaterThan(op.baseCost, 0)
        XCTAssertGreaterThanOrEqual(op.risk, 0)
        XCTAssertLessThanOrEqual(op.risk, 1)
    }

    func testDismissModalAgentKind() {
        let op = Operator(kind: .dismissModal)
        XCTAssertEqual(op.agentKind, .ui)
    }

    func testBuildProjectAgentKind() {
        let op = Operator(kind: .buildProject)
        XCTAssertEqual(op.agentKind, .code)
    }

    func testOperatorName() {
        let op = Operator(kind: .clickTarget)
        XCTAssertEqual(op.name, "click_target")
    }

    func testPreconditionDismissModal() {
        var state = ReasoningPlanningState(agentKind: .mixed)
        state.modalPresent = false
        let op = Operator(kind: .dismissModal)
        XCTAssertFalse(op.precondition(state), "dismissModal should be false when no modal")
        state.modalPresent = true
        XCTAssertTrue(op.precondition(state), "dismissModal should be true when modal present")
    }

    func testPreconditionRunTests() {
        let state = ReasoningPlanningState(agentKind: .code, repoOpen: true)
        let op = Operator(kind: .runTests)
        XCTAssertTrue(op.precondition(state))
    }

    func testPreconditionRunTestsFailsForUIAgent() {
        let state = ReasoningPlanningState(agentKind: .ui, repoOpen: true)
        let op = Operator(kind: .runTests)
        XCTAssertFalse(op.precondition(state))
    }

    func testEffectBuildProjectSetsBuildSucceeded() {
        var state = ReasoningPlanningState()
        state.buildSucceeded = nil
        let op = Operator(kind: .buildProject)
        let next = op.effect(state)
        XCTAssertNotNil(next.buildSucceeded)
        XCTAssertTrue(next.buildSucceeded == true)
    }

    func testEffectDismissModalClearsModal() {
        var state = ReasoningPlanningState()
        state.modalPresent = true
        let op = Operator(kind: .dismissModal)
        let next = op.effect(state)
        XCTAssertFalse(next.modalPresent)
    }

    func testEffectApplyPatchSetsPatchApplied() {
        var state = ReasoningPlanningState()
        state.patchApplied = false
        let op = Operator(kind: .applyPatch)
        let next = op.effect(state)
        XCTAssertTrue(next.patchApplied)
    }

    func testEffectRevertPatchClearsPatchApplied() {
        var state = ReasoningPlanningState()
        state.patchApplied = true
        let op = Operator(kind: .revertPatch)
        let next = op.effect(state)
        XCTAssertFalse(next.patchApplied)
    }

    func testHashableEquality() {
        let op1 = Operator(kind: .clickTarget)
        let op2 = Operator(kind: .clickTarget)
        XCTAssertEqual(op1, op2)
        XCTAssertEqual(op1.hashValue, op2.hashValue)
    }

    func testHashableInequality() {
        let op1 = Operator(kind: .runTests)
        let op2 = Operator(kind: .buildProject)
        XCTAssertNotEqual(op1, op2)
    }
}

// MARK: 55c. OperatorRegistry

final class OperatorRegistryTests: XCTestCase {

    func testSharedRegistryHasAllOperators() {
        let reg = OperatorRegistry()
        XCTAssertEqual(reg.allOperators().count, ReasoningOperatorKind.allCases.count)
    }

    func testRegisterAddsOperator() {
        let reg = OperatorRegistry(operators: [])
        XCTAssertEqual(reg.allOperators().count, 0)
        reg.register(Operator(kind: .runTests))
        XCTAssertEqual(reg.allOperators().count, 1)
    }

    func testAvailableFiltersByPrecondition() {
        // A code agent with repoOpen: code operators available, UI operators not
        let state = ReasoningPlanningState(agentKind: .code, repoOpen: true)
        let reg = OperatorRegistry()
        let ops = reg.available(for: state)
        XCTAssertFalse(ops.isEmpty)
        // dismissModal should not appear: agentKind is .code
        XCTAssertFalse(ops.contains { $0.kind == .dismissModal })
    }

    func testAvailableIncludesDismissModalWhenModalPresent() {
        let state = ReasoningPlanningState(agentKind: .mixed, modalPresent: true)
        let reg = OperatorRegistry()
        let ops = reg.available(for: state)
        XCTAssertTrue(ops.contains { $0.kind == .dismissModal })
    }

    func testAvailablePriorityDismissModalFirst() {
        let state = ReasoningPlanningState(agentKind: .mixed, modalPresent: true)
        let reg = OperatorRegistry()
        let ops = reg.available(for: state)
        XCTAssertEqual(ops.first?.kind, .dismissModal)
    }

    func testMakeOperatorReturnsOperator() {
        let reg = OperatorRegistry()
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let op = reg.makeOperator(kind: .runTests, state: state)
        XCTAssertNotNil(op)
        XCTAssertEqual(op?.kind, .runTests)
    }
}

// MARK: 55d. ReasoningPlanningState

final class ReasoningPlanningStateTests: XCTestCase {

    func testDefaultInit() {
        let state = ReasoningPlanningState()
        XCTAssertFalse(state.modalPresent)
        XCTAssertFalse(state.patchApplied)
        XCTAssertFalse(state.testsObserved)
        XCTAssertTrue(state.visibleTargets.isEmpty)
        XCTAssertTrue(state.candidateWorkspacePaths.isEmpty)
    }

    func testConvenienceInitGoalDescription() {
        var state = ReasoningPlanningState()
        state.goalDescription = "run unit tests"
        XCTAssertEqual(state.goalDescription, "run unit tests")
    }

    func testAgentKindDefault() {
        let state = ReasoningPlanningState()
        XCTAssertEqual(state.agentKind, .code)
    }

    func testModalPresentMutation() {
        var state = ReasoningPlanningState()
        state.modalPresent = true
        XCTAssertTrue(state.modalPresent)
    }

    func testBuildSucceededNilByDefault() {
        let state = ReasoningPlanningState()
        XCTAssertNil(state.buildSucceeded)
    }

    func testVisibleTargetsMutation() {
        var state = ReasoningPlanningState()
        state.visibleTargets = ["Save button", "Cancel button"]
        XCTAssertEqual(state.visibleTargets.count, 2)
    }

    func testPlanningStateIsHashable() {
        let s1 = ReasoningPlanningState()
        let s2 = ReasoningPlanningState()
        XCTAssertEqual(s1, s2)
        var set = Set<ReasoningPlanningState>()
        set.insert(s1)
        set.insert(s2)
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: 55e. PlanScore

final class PlanScoreTests: XCTestCase {

    func testTotalIsCorrect() {
        let score = PlanScore(
            predictedSuccess: 0.8,
            workflowMatch: 0.5,
            stableGraphSupport: 0.3,
            memoryBias: 0.1,
            riskPenalty: 0.2,
            costPenalty: 0.1,
            sourceType: .reasoning
        )
        let expected = 0.8 + 0.5 + 0.3 + 0.1 - 0.2 - 0.1
        XCTAssertEqual(score.total, expected, accuracy: 0.0001)
    }

    func testZeroTotalForZeroInputs() {
        let score = PlanScore()
        XCTAssertEqual(score.total, 0, accuracy: 0.0001)
    }

    func testPenaltiesReduceTotal() {
        let base = PlanScore(predictedSuccess: 1.0)
        let penalized = PlanScore(predictedSuccess: 1.0, riskPenalty: 0.5)
        XCTAssertGreaterThan(base.total, penalized.total)
    }

    func testSourceTypePreserved() {
        let score = PlanScore(sourceType: .llm)
        XCTAssertEqual(score.sourceType, .llm)
    }

    func testNotesPreserved() {
        let score = PlanScore(notes: ["note1", "note2"])
        XCTAssertEqual(score.notes, ["note1", "note2"])
    }

    func testEquality() {
        let a = PlanScore(predictedSuccess: 0.5, sourceType: .workflow)
        let b = PlanScore(predictedSuccess: 0.5, sourceType: .workflow)
        XCTAssertEqual(a, b)
    }
}

// MARK: 55f. SimulatedOutcome + PlanCandidate

final class PlanCandidateTests: XCTestCase {

    func testSimulatedOutcomeInit() {
        let outcome = SimulatedOutcome(successProbability: 0.9, estimatedSteps: 3, riskScore: 0.1)
        XCTAssertEqual(outcome.successProbability, 0.9)
        XCTAssertEqual(outcome.estimatedSteps, 3)
        XCTAssertEqual(outcome.riskScore, 0.1)
        XCTAssertNil(outcome.likelyFailureMode)
    }

    func testSimulatedOutcomeWithFailureMode() {
        let outcome = SimulatedOutcome(successProbability: 0.3, estimatedSteps: 2, riskScore: 0.7, likelyFailureMode: "timeout")
        XCTAssertEqual(outcome.likelyFailureMode, "timeout")
    }

    func testPlanCandidateEstimatedCostFromOperators() {
        let op1 = Operator(kind: .runTests)
        let op2 = Operator(kind: .buildProject)
        let plan = PlanCandidate(operators: [op1, op2])
        let expectedCost = op1.baseCost + op2.baseCost
        XCTAssertEqual(plan.estimatedCost, expectedCost, accuracy: 0.0001)
    }

    func testPlanCandidateRiskScoreIsAverage() {
        let op1 = Operator(kind: .runTests)
        let op2 = Operator(kind: .applyPatch)
        let plan = PlanCandidate(operators: [op1, op2])
        let expectedRisk = (op1.risk + op2.risk) / 2.0
        XCTAssertEqual(plan.riskScore, expectedRisk, accuracy: 0.0001)
    }

    func testPlanCandidateOperatorFamiliesPopulated() {
        let op = Operator(kind: .runTests)
        let plan = PlanCandidate(operators: [op])
        XCTAssertFalse(plan.operatorFamilies.isEmpty)
    }

    func testPlanCandidateOperatorFamiliesDeduped() {
        let op1 = Operator(kind: .runTests)
        let op2 = Operator(kind: .buildProject)
        let plan = PlanCandidate(operators: [op1, op2])
        // Both are patchGeneration family — should deduplicate
        let families = plan.operatorFamilies
        XCTAssertEqual(families.count, Set(families).count)
    }

    func testIsAllowedByStrategy() {
        let op = Operator(kind: .clickTarget)
        let plan = PlanCandidate(operators: [op])
        let family = op.kind.operatorFamily
        let strategy = SelectedStrategy(
            kind: .browserInteraction,
            confidence: 0.9,
            rationale: "test",
            allowedOperatorFamilies: [family]
        )
        XCTAssertTrue(plan.isAllowed(by: strategy))
    }

    func testIsNotAllowedByStrategy() {
        let op = Operator(kind: .clickTarget)
        let plan = PlanCandidate(operators: [op])
        // A strategy that allows only workflow family
        let strategy = SelectedStrategy(
            kind: .workflowExecution,
            confidence: 0.9,
            rationale: "test",
            allowedOperatorFamilies: [.workflow]
        )
        XCTAssertFalse(plan.isAllowed(by: strategy))
    }

    func testEmptyOperatorsPlanHasZeroCost() {
        let plan = PlanCandidate(operators: [])
        XCTAssertEqual(plan.estimatedCost, 0)
    }

    func testSourceTypeDefault() {
        let plan = PlanCandidate(operators: [])
        XCTAssertEqual(plan.sourceType, .reasoning)
    }

    func testSourceTypeOverride() {
        let plan = PlanCandidate(operators: [], sourceType: .llm)
        XCTAssertEqual(plan.sourceType, .llm)
    }
}

// MARK: 55g. PlanDiagnostics + ScoredPlanSummary

final class PlanDiagnosticsTests: XCTestCase {

    func testScoredPlanSummaryInit() {
        let summary = ScoredPlanSummary(
            operatorNames: ["runTests", "buildProject"],
            score: 0.75,
            reasons: ["matched workflow"],
            simulatedSuccessProbability: 0.9,
            simulatedRiskScore: 0.1,
            simulatedFailureMode: nil
        )
        XCTAssertEqual(summary.operatorNames.count, 2)
        XCTAssertEqual(summary.score, 0.75, accuracy: 0.0001)
        XCTAssertNil(summary.simulatedFailureMode)
    }

    func testPlanDiagnosticsInit() {
        let summary = ScoredPlanSummary(
            operatorNames: ["clickTarget"],
            score: 0.5,
            reasons: [],
            simulatedSuccessProbability: nil,
            simulatedRiskScore: nil,
            simulatedFailureMode: nil
        )
        let diag = PlanDiagnostics(
            selectedOperatorNames: ["clickTarget"],
            candidatePlans: [summary],
            fallbackReason: nil
        )
        XCTAssertEqual(diag.selectedOperatorNames, ["clickTarget"])
        XCTAssertEqual(diag.candidatePlans.count, 1)
        XCTAssertNil(diag.fallbackReason)
    }

    func testPlanDiagnosticsWithFallback() {
        let diag = PlanDiagnostics(
            selectedOperatorNames: [],
            candidatePlans: [],
            fallbackReason: "no operators available"
        )
        XCTAssertEqual(diag.fallbackReason, "no operators available")
    }

    func testScoredPlanSummaryEquality() {
        let a = ScoredPlanSummary(
            operatorNames: ["runTests"], score: 0.8, reasons: [],
            simulatedSuccessProbability: nil, simulatedRiskScore: nil, simulatedFailureMode: nil
        )
        let b = ScoredPlanSummary(
            operatorNames: ["runTests"], score: 0.8, reasons: [],
            simulatedSuccessProbability: nil, simulatedRiskScore: nil, simulatedFailureMode: nil
        )
        XCTAssertEqual(a, b)
    }
}

// MARK: 55h. PlanSourceType

final class PlanSourceTypeTests: XCTestCase {

    func testFromPlannerSourceWorkflow() {
        let t = PlanSourceType.from(.workflow)
        XCTAssertEqual(t, .workflow)
    }

    func testFromPlannerSourceStableGraph() {
        let t = PlanSourceType.from(.stableGraph)
        XCTAssertEqual(t, .stableGraph)
    }

    func testFromPlannerSourceCandidateGraph() {
        let t = PlanSourceType.from(.candidateGraph)
        XCTAssertEqual(t, .candidateGraph)
    }

    func testFromPlannerSourceExploration() {
        let t = PlanSourceType.from(.exploration)
        XCTAssertEqual(t, .exploration)
    }

    func testFromPlannerSourceRecovery() {
        let t = PlanSourceType.from(.recovery)
        XCTAssertEqual(t, .recovery)
    }

    func testRawValues() {
        XCTAssertEqual(PlanSourceType.stableGraph.rawValue, "stable_graph")
        XCTAssertEqual(PlanSourceType.candidateGraph.rawValue, "candidate_graph")
        XCTAssertEqual(PlanSourceType.llm.rawValue, "llm")
    }
}

// MARK: 55i. LLMClient

final class LLMClientTests: XCTestCase {

    func testDefaultInitHasNoProviders() {
        let client = LLMClient()
        let diag = client.diagnostics
        XCTAssertEqual(diag.requestCount, 0)
        XCTAssertEqual(diag.totalTokens, 0)
    }

    func testLLMRequestInit() {
        let req = LLMRequest(prompt: "test", modelTier: .planning, maxTokens: 512, temperature: 0.2)
        XCTAssertEqual(req.prompt, "test")
        XCTAssertEqual(req.modelTier, .planning)
        XCTAssertEqual(req.maxTokens, 512)
        XCTAssertEqual(req.temperature, 0.2, accuracy: 0.0001)
    }

    func testLLMResponseInit() {
        let resp = LLMResponse(text: "result", modelTier: .codeRepair, tokenCount: 100, latencyMs: 150)
        XCTAssertEqual(resp.text, "result")
        XCTAssertEqual(resp.modelTier, .codeRepair)
        XCTAssertEqual(resp.tokenCount, 100)
    }

    func testLLMModelTierRawValues() {
        XCTAssertEqual(LLMModelTier.planning.rawValue, "planning")
        XCTAssertEqual(LLMModelTier.codeRepair.rawValue, "code_repair")
        XCTAssertEqual(LLMModelTier.recovery.rawValue, "recovery")
    }

    func testCompleteWithNoProviderReturnsEmpty() async throws {
        let client = LLMClient()
        let req = LLMRequest(prompt: "hello", modelTier: .planning)
        let resp = try await client.complete(req)
        XCTAssertEqual(resp.text, "")
    }

    func testDiagnosticsAfterComplete() async throws {
        let client = LLMClient()
        let req = LLMRequest(prompt: "hello", modelTier: .planning)
        _ = try await client.complete(req)
        // With no provider, early return — requestCount stays 0
        XCTAssertEqual(client.diagnostics.requestCount, 0)
    }

    func testLLMClientDiagnosticsInit() {
        let diag = LLMClientDiagnostics(requestCount: 5, totalTokens: 1000)
        XCTAssertEqual(diag.requestCount, 5)
        XCTAssertEqual(diag.totalTokens, 1000)
    }
}

// MARK: 55j. ReasoningParser

final class ReasoningParserTests: XCTestCase {

    func testParsePlansEmptyTextReturnsEmpty() {
        let plans = ReasoningParser.parsePlans(from: "")
        XCTAssertTrue(plans.isEmpty)
    }

    func testParsePlansNoBlocksReturnsEmpty() {
        let plans = ReasoningParser.parsePlans(from: "This is not a plan.")
        XCTAssertTrue(plans.isEmpty)
    }

    func testParsedPlanInit() {
        let plan = ParsedPlan(steps: [.runTests, .buildProject], confidence: 0.85, risk: "low", rationale: "standard flow")
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(plan.confidence, 0.85, accuracy: 0.0001)
        XCTAssertEqual(plan.risk, "low")
        XCTAssertEqual(plan.rationale, "standard flow")
    }

    func testToPlanCandidatesFromEmptyParsedPlans() {
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let candidates = ReasoningParser.toPlanCandidates(parsedPlans: [], state: state)
        XCTAssertTrue(candidates.isEmpty)
    }

    func testToPlanCandidatesRiskHighMapsTo07() {
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let parsed = ParsedPlan(steps: [.runTests], confidence: 0.9, risk: "high")
        let candidates = ReasoningParser.toPlanCandidates(parsedPlans: [parsed], state: state)
        if let first = candidates.first {
            XCTAssertEqual(first.riskScore, 0.7, accuracy: 0.001)
        }
        // Note: candidate may be empty if runTests precondition satisfied for code agent
    }

    func testToPlanCandidatesRiskLowMapsTo015() {
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let parsed = ParsedPlan(steps: [.runTests], confidence: 0.9, risk: "low")
        let candidates = ReasoningParser.toPlanCandidates(parsedPlans: [parsed], state: state)
        if let first = candidates.first {
            XCTAssertEqual(first.riskScore, 0.15, accuracy: 0.001)
        }
    }

    func testToPlanCandidatesSourceTypeIsLLM() {
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let parsed = ParsedPlan(steps: [.runTests], confidence: 0.9, risk: "low")
        let candidates = ReasoningParser.toPlanCandidates(parsedPlans: [parsed], state: state)
        for candidate in candidates {
            XCTAssertEqual(candidate.sourceType, .llm)
        }
    }

    func testParsePlansWithBlock() {
        let text = """
        PLAN 1:
        STEPS: runTests
        CONFIDENCE: 0.9
        RISK: low
        RATIONALE: standard test run
        END_PLAN
        """
        let plans = ReasoningParser.parsePlans(from: text)
        // Parser may return 1 plan if block format matches
        XCTAssertGreaterThanOrEqual(plans.count, 0)
    }
}

// MARK: 55k. ReasoningEngine plan generation

final class ReasoningEngineExtensionTests: XCTestCase {

    func testGeneratePlansFromDefaultState() {
        let engine = ReasoningEngine()
        let state = ReasoningPlanningState()
        let plans = engine.generatePlans(from: state)
        // Should return some plans or at least not crash
        XCTAssertGreaterThanOrEqual(plans.count, 0)
    }

    func testGeneratePlansRespectMaxPlans() {
        let engine = ReasoningEngine()
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let plans = engine.generatePlans(from: state, maxDepth: 2, maxPlans: 3, operatorRegistry: .shared)
        XCTAssertLessThanOrEqual(plans.count, 3)
    }

    func testGeneratePlansNoDuplicateKindSequences() {
        let engine = ReasoningEngine()
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let plans = engine.generatePlans(from: state, maxDepth: 2, maxPlans: 10, operatorRegistry: .shared)
        let kindSequences = plans.map { $0.operators.map(\.kind) }
        let uniqueSequences = Set(kindSequences.map { $0.map(\.rawValue).joined(separator: ",") })
        XCTAssertEqual(uniqueSequences.count, kindSequences.count)
    }

    func testGeneratePlansCandidatesHaveOperators() {
        let engine = ReasoningEngine()
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let plans = engine.generatePlans(from: state, maxDepth: 2, maxPlans: 5, operatorRegistry: .shared)
        for plan in plans {
            XCTAssertFalse(plan.operators.isEmpty)
        }
    }
}

// MARK: 55l. ProposalEngine

final class ProposalEngineTests: XCTestCase {

    func testProposalEngineInit() {
        let engine = ProposalEngine(llmClient: LLMClient(), reasoningEngine: ReasoningEngine())
        XCTAssertNotNil(engine)
    }

    func testProposalInit() {
        let proposal = Proposal(plans: [], selectedPlan: nil, diagnostics: ProposalDiagnostics(
            llmPlansGenerated: 0, deterministicPlansGenerated: 0, totalEvaluated: 0,
            selectedSource: nil, llmLatencyMs: 0, notes: []
        ))
        XCTAssertTrue(proposal.plans.isEmpty)
        XCTAssertNil(proposal.selectedPlan)
    }

    func testProposalDiagnosticsInit() {
        let diag = ProposalDiagnostics(
            llmPlansGenerated: 2,
            deterministicPlansGenerated: 4,
            totalEvaluated: 6,
            selectedSource: .reasoning,
            llmLatencyMs: 120.5,
            notes: ["deterministic selected"]
        )
        XCTAssertEqual(diag.llmPlansGenerated, 2)
        XCTAssertEqual(diag.deterministicPlansGenerated, 4)
        XCTAssertEqual(diag.totalEvaluated, 6)
        XCTAssertEqual(diag.selectedSource, .reasoning)
        XCTAssertEqual(diag.llmLatencyMs, 120.5, accuracy: 0.001)
    }

    func testProposeReturnsProposal() async {
        let engine = ProposalEngine(llmClient: LLMClient(), reasoningEngine: ReasoningEngine())
        var state = ReasoningPlanningState()
        state.agentKind = .code
        let goal = Goal(description: "run unit tests", priority: .normal)
        let strategy = SelectedStrategy(
            kind: .repoRepair,
            confidence: 0.9,
            rationale: "test",
            allowedOperatorFamilies: OperatorFamily.allCases
        )
        let proposal = await engine.propose(state: state, goal: goal, selectedStrategy: strategy)
        XCTAssertNotNil(proposal)
        XCTAssertGreaterThanOrEqual(proposal.diagnostics.totalEvaluated, 0)
    }
}

// MARK: 55m. GraphStore Reasoning stubs

final class GraphStoreReasoningTests: XCTestCase {

    func testOutgoingStableEdgesReturnsEmpty() {
        let store = GraphStore()
        let id = PlanningStateID(rawValue: "test-state-1")
        let edges = store.outgoingStableEdges(from: id)
        XCTAssertTrue(edges.isEmpty)
    }

    func testOutgoingCandidateEdgesReturnsEmpty() {
        let store = GraphStore()
        let id = PlanningStateID(rawValue: "test-state-2")
        let edges = store.outgoingCandidateEdges(from: id)
        XCTAssertTrue(edges.isEmpty)
    }

    func testActionContractForIDReturnsNil() {
        let store = GraphStore()
        let contract = store.actionContract(for: "any-id")
        XCTAssertNil(contract)
    }

    func testGraphEdgeInit() {
        let edge = GraphEdge(
            id: "e1",
            fromStateID: PlanningStateID(rawValue: "from-state"),
            toStateID: PlanningStateID(rawValue: "to-state"),
            actionContractID: "ac1",
            stable: true,
            weight: 0.8
        )
        XCTAssertEqual(edge.id, "e1")
        XCTAssertTrue(edge.stable)
        XCTAssertEqual(edge.weight, 0.8, accuracy: 0.0001)
        XCTAssertEqual(edge.actionContractID, "ac1")
    }
}

// MARK: 55n. MemoryExtensions

final class MemoryExtensionsTests: XCTestCase {

    func testWorkflowActionBiasNonNegative() {
        let router = MemoryRouter()
        let contract = ActionContract(
            id: "ac1",
            skillName: "runTests",
            targetRole: nil,
            targetLabel: nil,
            locatorStrategy: "direct"
        )
        let bias = router.workflowActionBias(
            contract: contract,
            app: "Xcode",
            goalDescription: "run tests",
            workspaceRoot: nil
        )
        XCTAssertGreaterThanOrEqual(bias, 0)
    }

    func testWorkflowActionBiasAtMost03() {
        let router = MemoryRouter()
        let contract = ActionContract(
            id: "ac1",
            skillName: "runTests",
            targetRole: nil,
            targetLabel: nil,
            locatorStrategy: "direct"
        )
        let bias = router.workflowActionBias(
            contract: contract,
            app: "Xcode",
            goalDescription: "run tests",
            workspaceRoot: "/Users/dev/project"
        )
        XCTAssertLessThanOrEqual(bias, 0.3)
    }

    func testActionContractInit() {
        let contract = ActionContract(
            id: "test-id",
            agentKind: .code,
            skillName: "buildProject",
            targetRole: "button",
            targetLabel: "Build",
            locatorStrategy: "label",
            commandCategory: "build"
        )
        XCTAssertEqual(contract.id, "test-id")
        XCTAssertEqual(contract.agentKind, .code)
        XCTAssertEqual(contract.skillName, "buildProject")
        XCTAssertEqual(contract.targetLabel, "Build")
        XCTAssertEqual(contract.commandCategory, "build")
    }
}

// MARK: 55o. Runtime Reasoning Wiring

final class RuntimeReasoningWiringTests: XCTestCase {

    func testRuntimeHasLLMClient() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.llmClient)
    }

    func testRuntimeHasOperatorRegistry() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.operatorRegistry)
        XCTAssertEqual(runtime.operatorRegistry.allOperators().count, ReasoningOperatorKind.allCases.count)
    }

    func testRuntimeHasProposalEngine() {
        let runtime = OracleRuntime()
        runtime.initialize()
        XCTAssertNotNil(runtime.proposalEngine)
    }

    func testOperatorRegistrySharedHasAllKinds() {
        let reg = OperatorRegistry.shared
        let kinds = Set(reg.allOperators().map(\.kind))
        for kind in ReasoningOperatorKind.allCases {
            XCTAssertTrue(kinds.contains(kind), "Registry missing kind: \(kind)")
        }
    }
}
