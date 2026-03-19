import Core
import Foundation

enum Bootstrap {
    static func makeRuntime() -> AgentRuntime {
        let workspaceRoot = URL(
            fileURLWithPath: "workspace",
            relativeTo: URL(fileURLWithPath: ".")
        ).standardizedFileURL.path
        let policy = ExecutionPolicy(
            allowedShellCommands: ["ls", "echo", "cat"],
            allowedWriteRoots: [workspaceRoot],
            networkWhitelist: ["example.com"],
            maxExecutionTime: 3,
            maxOutputBytes: 20_000
        )
        let store = FileEventStore(path: "events.log")
        let loop = AgentLoop(
            planner: BasicPlanner(),
            resolver: CommandResolver(),
            executor: VerifiedExecutor(policy: PolicyEngine(policy: policy)),
            store: store,
            reducer: DefaultReducer(),
            critic: BasicCritic(),
            repair: RepairEngine()
        )

        return AgentRuntime(loop: loop)
    }
}
