import Core
import Foundation
import XCTest

final class ReplayDeterminismTests: XCTestCase {
    func test_replay_matches_live_state() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let eventsPath = root.appendingPathComponent("events.jsonl", isDirectory: false).path

        let store = FileEventStore(path: eventsPath)
        let reducer = DefaultReducer()
        let runtime = AgentRuntime(
            loop: AgentLoop(
                planner: BasicPlanner(),
                resolver: CommandResolver(),
                executor: VerifiedExecutor(policy: PolicyEngine()),
                store: store,
                reducer: reducer,
                critic: BasicCritic(),
                repair: RepairEngine()
            )
        )

        let goal = Goal(text: "write file a.txt live-replay-check")
        let live = try runtime.run(goal: goal)
        let replayed = try ReplayEngine(store: store, reducer: reducer).rebuild()

        XCTAssertEqual(live, replayed)
    }
}
