import Core
import XCTest

final class RuntimeContractTests: XCTestCase {
    func test_command_resolver_returns_commands_unchanged() {
        let resolver = CommandResolver()
        let commands = resolver.normalize([
            Command(type: "file.write", payload: ["path": "workspace/a.txt", "content": "hello"]),
            Command(type: "shell", payload: ["cmd": "echo ok"]),
        ])

        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0].type, "file.write")
        XCTAssertEqual(commands[0].stringValue(for: "path"), "workspace/a.txt")
        XCTAssertEqual(commands[0].stringValue(for: "content"), "hello")
        XCTAssertEqual(commands[1].type, "shell")
        XCTAssertEqual(commands[1].stringValue(for: "cmd"), "echo ok")
    }

    func test_in_memory_event_store_preserves_append_order() throws {
        let store = InMemoryEventStore()
        let command = Command(type: "file.write", payload: ["path": "workspace/a.txt", "content": "hello"])
        let events: [any DomainEvent] = [
            FileWriteEvent(commandID: command.id, path: "workspace/a.txt", content: "hello"),
            ShellExecutedEvent(commandID: command.id, command: "echo hi", output: "hi", status: 0),
        ]

        try store.append(events)
        let envelopes = try store.load()

        XCTAssertEqual(envelopes.count, 2)
        XCTAssertEqual(envelopes[0].commandID, command.id)
        XCTAssertEqual(envelopes[1].commandID, command.id)
    }

    func test_policy_rejects_root_write() {
        let policy = PolicyEngine(policy: makePolicy())
        let command = Command(type: "file.write", payload: ["path": "/etc/passwd", "content": "nope"])

        XCTAssertThrowsError(try policy.validate(command)) { error in
            XCTAssertEqual(
                (error as? RuntimeError)?.errorDescription,
                "Write path blocked: /etc/passwd"
            )
        }
    }

    func test_policy_rejects_blocked_command() {
        let policy = PolicyEngine(policy: makePolicy())
        let command = Command(type: "shell", payload: ["cmd": "rm -rf /"])

        XCTAssertThrowsError(try policy.validate(command)) { error in
            XCTAssertEqual(
                (error as? RuntimeError)?.errorDescription,
                "Command not allowed: rm"
            )
        }
    }

    func test_executor_times_out_long_running_shell_command() {
        let policy = ExecutionPolicy(
            allowedShellCommands: ["sleep"],
            allowedWriteRoots: [workspaceRoot()],
            networkWhitelist: [],
            maxExecutionTime: 0.05,
            maxOutputBytes: 1_024
        )
        let executor = VerifiedExecutor(policy: PolicyEngine(policy: policy))
        let command = Command(type: "shell", payload: ["cmd": "sleep 10"])

        XCTAssertThrowsError(try executor.execute(command)) { error in
            XCTAssertEqual(
                (error as? RuntimeError)?.errorDescription,
                "Execution timed out"
            )
        }
    }

    func test_microvm_runner_builds_firecracker_config_with_encoded_command() throws {
        let runner = MicroVMRunner(
            configuration: MicroVMConfiguration(
                firecrackerBinaryPath: "/usr/local/bin/firecracker",
                kernelImagePath: "/tmp/vmlinux",
                rootfsPath: "/tmp/rootfs.ext4",
                workspaceImagePath: "/tmp/workspace.ext4",
                vcpuCount: 2,
                memoryMiB: 256
            )
        )

        let plan = try runner.invocationPlan(
            command: "echo hello",
            apiSocketPath: "/tmp/firecracker.sock",
            configFilePath: "/tmp/firecracker.json"
        )

        XCTAssertEqual(plan.executablePath, "/usr/local/bin/firecracker")
        XCTAssertEqual(plan.arguments, ["--api-sock", "/tmp/firecracker.sock", "--config-file", "/tmp/firecracker.json"])
        XCTAssertTrue(plan.configJSON.contains("\"kernel_image_path\" : \"/tmp/vmlinux\""))
        XCTAssertTrue(plan.configJSON.contains("\"path_on_host\" : \"/tmp/rootfs.ext4\""))
        XCTAssertTrue(plan.configJSON.contains("\"path_on_host\" : \"/tmp/workspace.ext4\""))
        XCTAssertTrue(plan.configJSON.contains("oracle_cmd_b64="))
    }

    func test_runtime_runs_write_goal_through_single_path() async throws {
        let runtime = AgentRuntime(
            loop: AgentLoop(
                planner: BasicPlanner(),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine(policy: makePolicy())),
                store: InMemoryEventStore(),
                reducer: DefaultReducer(),
                critic: BasicCritic(),
                repair: RepairEngine()
            )
        )

        let state = try await runtime.run(goal: Goal(text: "write file workspace/a.txt hello"))

        XCTAssertEqual(state.files["workspace/a.txt"], "hello")
        XCTAssertTrue(state.executionTrace.contains("file.write"))
    }

    func test_critic_does_not_treat_preexisting_file_as_success_without_write_event() {
        let critic = BasicCritic()
        let state = WorldState(files: ["workspace/a.txt": "old"])

        let evaluation = critic.evaluate(
            goal: Goal(text: "write file workspace/a.txt new"),
            events: [],
            state: state
        )

        XCTAssertFalse(evaluation.success)
    }
}

private func makePolicy() -> ExecutionPolicy {
    ExecutionPolicy(
        allowedShellCommands: ["ls", "echo", "cat"],
        allowedWriteRoots: [workspaceRoot()],
        networkWhitelist: ["example.com"],
        maxExecutionTime: 0.5,
        maxOutputBytes: 4_096
    )
}

private func workspaceRoot(filePath: String = #filePath) -> String {
    let repositoryRoot = ScanSupport.repositoryRoot(filePath: filePath)
    return repositoryRoot.appendingPathComponent("workspace", isDirectory: true).standardizedFileURL.path
}
