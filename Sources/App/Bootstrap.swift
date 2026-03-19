import Core
import Foundation

enum Bootstrap {
    static func makeRuntime(
        eventLogPath: String = URL(
            fileURLWithPath: "Observability/runtime/events.jsonl",
            relativeTo: URL(fileURLWithPath: ".")
        ).standardizedFileURL.path
    ) -> AgentRuntime {
        let store = FileEventStore(path: eventLogPath)
        let loop = AgentLoop(
            planner: BasicPlanner(),
            resolver: CommandResolver(),
            executor: VerifiedExecutor(policy: PolicyEngine()),
            store: store,
            reducer: DefaultReducer(),
            critic: BasicCritic(),
            repair: RepairEngine()
        )

        return AgentRuntime(loop: loop)
    }
}
