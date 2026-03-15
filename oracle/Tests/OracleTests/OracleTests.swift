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

        let traces = store.recentTraces(limit: 5)
        XCTAssertFalse(traces.isEmpty, "Should have at least one trace after recording")
        XCTAssertEqual(traces.first?.actionType, "test_write")
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
