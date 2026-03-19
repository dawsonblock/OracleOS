import Core
import MultiAgent
import XCTest

final class MultiAgentContractTests: XCTestCase {
    func test_planned_commands_are_normalized() throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "workspace/runtime-output.txt", "content": "ok"])])]
        )

        let batches = coordinator.plannedCommands(goal: Goal(text: "ignored"), state: try runtime.currentState())

        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].commands.first?.type, "file.write")
        XCTAssertEqual(batches[0].commands.first?.stringValue(for: "path"), "workspace/runtime-output.txt")
    }

    func test_conflicting_file_writes_are_rejected() async throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "workspace/shared.txt", "content": "a"])]),
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "workspace/shared.txt", "content": "b"])]),
            ]
        )

        await XCTAssertThrowsErrorAsync(try await coordinator.run(goal: Goal(text: "ignored"))) { error in
            XCTAssertEqual(
                (error as? MultiAgentError)?.errorDescription,
                "Conflicting file commands detected: workspace/shared.txt"
            )
        }
    }

    func test_non_conflicting_planners_accumulate_state() async throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "workspace/a.txt", "content": "one"])]),
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "workspace/b.txt", "content": "two"])]),
            ]
        )

        let state = try await coordinator.run(goal: Goal(text: "ignored"))

        XCTAssertEqual(state.files["workspace/a.txt"], "one")
        XCTAssertEqual(state.files["workspace/b.txt"], "two")
        XCTAssertEqual(state.executedCommandIDs.count, 2)
    }

    func test_state_sensitive_planner_uses_current_state_when_executed() async throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "workspace/a.txt", "content": "one"])]),
                StateAwarePlanner(),
            ]
        )

        let state = try await coordinator.run(goal: Goal(text: "ignored"))

        XCTAssertEqual(state.files["workspace/a.txt"], "one")
        XCTAssertEqual(state.files["workspace/b.txt"], "derived")
    }

    private func makeRuntime() -> AgentRuntime {
        let policy = ExecutionPolicy(
            allowedShellCommands: ["ls", "echo", "cat"],
            allowedWriteRoots: [workspaceRoot()],
            networkWhitelist: ["example.com"],
            maxExecutionTime: 0.5,
            maxOutputBytes: 4_096
        )
        AgentRuntime(
            loop: AgentLoop(
                planner: BasicPlanner(),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine(policy: policy)),
                store: InMemoryEventStore(),
                reducer: DefaultReducer(),
                critic: BasicCritic(),
                repair: RepairEngine()
            )
        )
    }
}

private struct FixedPlanner: Planner {
    let commands: [Command]

    func plan(goal: Goal, state: WorldState) -> [Command] {
        commands
    }
}

private struct StateAwarePlanner: Planner {
    func plan(goal: Goal, state: WorldState) -> [Command] {
        guard state.files["workspace/a.txt"] == "one" else {
            return []
        }

        return [Command(type: "file.write", payload: ["path": "workspace/b.txt", "content": "derived"])]
    }
}

private func workspaceRoot(filePath: String = #filePath) -> String {
    let repositoryRoot = ScanSupport.repositoryRoot(filePath: filePath)
    return repositoryRoot.appendingPathComponent("workspace", isDirectory: true).standardizedFileURL.path
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
