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
