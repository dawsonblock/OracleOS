import Core
import MultiAgent
import XCTest

final class MultiAgentContractTests: XCTestCase {
    func test_planned_commands_are_normalized() throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [FixedPlanner(commands: [Command(type: " File.Write ", payload: [:])])]
        )

        let batches = coordinator.plannedCommands(goal: Goal(text: "ignored"), state: try runtime.currentState())

        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].commands.first?.type, "file.write")
        XCTAssertEqual(batches[0].commands.first?.payload["path"], "runtime-output.txt")
    }

    func test_conflicting_file_writes_are_rejected() throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "shared.txt", "content": "a"])]),
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "shared.txt", "content": "b"])]),
            ]
        )

        XCTAssertThrowsError(try coordinator.run(goal: Goal(text: "ignored"))) { error in
            XCTAssertEqual(
                (error as? MultiAgentError)?.errorDescription,
                "Conflicting file.write commands detected: shared.txt"
            )
        }
    }

    func test_non_conflicting_planners_accumulate_state() throws {
        let runtime = makeRuntime()
        let coordinator = MultiAgentCoordinator(
            runtime: runtime,
            planners: [
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "a.txt", "content": "one"])]),
                FixedPlanner(commands: [Command(type: "file.write", payload: ["path": "b.txt", "content": "two"])]),
            ]
        )

        let state = try coordinator.run(goal: Goal(text: "ignored"))

        XCTAssertEqual(state.files["a.txt"], "one")
        XCTAssertEqual(state.files["b.txt"], "two")
        XCTAssertEqual(state.executedCommandIDs.count, 2)
    }

    private func makeRuntime() -> AgentRuntime {
        AgentRuntime(
            loop: AgentLoop(
                planner: BasicPlanner(),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine()),
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
