import Core
import Foundation
import XCTest

final class ReplayDeterminismTests: XCTestCase {
    func test_replay_matches_live_state() async throws {
        let store = InMemoryEventStore()
        let reducer = DefaultReducer()
        let policy = ExecutionPolicy(
            allowedShellCommands: ["ls", "echo", "cat"],
            allowedWriteRoots: [workspaceRoot()],
            networkWhitelist: ["example.com"],
            maxExecutionTime: 0.5,
            maxOutputBytes: 4_096
        )
        let runtime = AgentRuntime(
            loop: AgentLoop(
                planner: BasicPlanner(),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine(policy: policy)),
                store: store,
                reducer: reducer,
                critic: BasicCritic(),
                repair: RepairEngine()
            )
        )

        let goal = Goal(text: "write file workspace/a.txt live-replay-check")
        let live = try await runtime.run(goal: goal)
        let replayed = try ReplayEngine(store: store, reducer: reducer).rebuild()

        XCTAssertEqual(live, replayed)
    }
}

private func workspaceRoot(filePath: String = #filePath) -> String {
    let repositoryRoot = ScanSupport.repositoryRoot(filePath: filePath)
    return repositoryRoot.appendingPathComponent("workspace", isDirectory: true).standardizedFileURL.path
}
