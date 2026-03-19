import Core
import XCTest

final class RuntimeContractTests: XCTestCase {
    func test_command_resolver_normalizes_payloads() {
        let resolver = CommandResolver()
        let commands = resolver.normalize([
            Command(type: " File.Write ", payload: [:]),
            Command(type: "http.request", payload: ["url": "https://example.com", "method": "post", "timeout_ms": "999999"]),
            Command(type: "shell", payload: ["cmd": " echo ok ", "timeout_ms": "0"]),
        ])

        XCTAssertEqual(commands[0].type, "file.write")
        XCTAssertEqual(commands[0].payload["path"], "runtime-output.txt")
        XCTAssertEqual(commands[0].payload["content"], "")
        XCTAssertEqual(commands[1].payload["method"], "POST")
        XCTAssertEqual(commands[1].payload["timeout_ms"], "300000")
        XCTAssertEqual(commands[2].payload["cmd"], "echo ok")
        XCTAssertEqual(commands[2].payload["timeout_ms"], "30000")
    }

    func test_in_memory_event_store_preserves_append_order() throws {
        let store = InMemoryEventStore()
        let command = Command(type: "file.write", payload: ["path": "a.txt", "content": "hello"])
        let events: [any DomainEvent] = [
            FileWriteRequestedEvent(commandID: command.id, path: "a.txt", content: "hello"),
            ShellExecutedEvent(commandID: command.id, command: "echo hi", output: "hi", status: 0, durationMillis: 5),
        ]

        try store.append(events)
        let envelopes = try store.load()

        XCTAssertEqual(envelopes.count, 2)
        XCTAssertEqual(envelopes[0].commandID, command.id)
        XCTAssertEqual(envelopes[1].commandID, command.id)
    }

    func test_policy_rejects_file_path_traversal() {
        let policy = PolicyEngine()
        let command = Command(type: "file.write", payload: ["path": "../escape.txt", "content": "nope"])

        XCTAssertThrowsError(try policy.validate(command)) { error in
            XCTAssertEqual(
                (error as? RuntimeError)?.errorDescription,
                "File commands must stay within the workspace root"
            )
        }
    }

    func test_policy_rejects_timeout_above_limit() {
        let policy = PolicyEngine()
        let command = Command(type: "shell", payload: ["cmd": "echo hi", "timeout_ms": "300001"])

        XCTAssertThrowsError(try policy.validate(command)) { error in
            XCTAssertEqual(
                (error as? RuntimeError)?.errorDescription,
                "Execution timeout exceeds maximum allowed value of 300000ms"
            )
        }
    }

    func test_executor_times_out_long_running_shell_command() {
        let executor = VerifiedExecutor(policy: PolicyEngine())
        let command = Command(type: "shell", payload: ["cmd": "sleep 1", "timeout_ms": "1"])

        XCTAssertThrowsError(try executor.execute(command)) { error in
            XCTAssertEqual(
                (error as? RuntimeError)?.errorDescription,
                "shell execution timed out after 1ms"
            )
        }
    }

    func test_runtime_run_result_surfaces_failed_command_state() throws {
        let runtime = AgentRuntime(
            loop: AgentLoop(
                planner: FixedPlanner(commands: [
                    Command(type: "file.write", payload: ["path": "../escape.txt", "content": "blocked"]),
                ]),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine()),
                store: InMemoryEventStore(),
                reducer: DefaultReducer(),
                critic: BasicCritic(),
                repair: RepairEngine()
            )
        )

        let result = try runtime.runResult(goal: Goal(text: "write file ../escape.txt blocked"))

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.state.failureCount, 1)
        XCTAssertEqual(result.state.lastFailedCommandType, "file.write")
        XCTAssertEqual(result.state.lastFailure, "File commands must stay within the workspace root")
        XCTAssertFalse(result.state.lastFailureTimedOut)
        XCTAssertTrue(result.issues.contains("File commands must stay within the workspace root"))
    }
}

private struct FixedPlanner: Planner {
    let commands: [Command]

    func plan(goal: Goal, state: WorldState) -> [Command] {
        commands
    }
}
