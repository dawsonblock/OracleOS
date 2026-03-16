import sys

content = """import Foundation
import Testing
@testable import OracleOS

@Suite("WorldModel AgentLoop Wiring")
struct WorldModelAgentLoopWiringTests {

    @Test("WorldStateModel accepts StateDiff from StateDiffEngine")
    func worldModelAppliesDiff() {
        let model = WorldStateModel()
        let obs = Observation(
            app: "TestApp",
            windowTitle: "Window A",
            focusedElementID: "",
            elements: []
        )
        let planningState = PlanningState(id: PlanningStateID(rawValue: "state-1"), clusterKey: StateClusterKey(rawValue: "c"), appID: "TestApp", domain: nil, windowClass: nil, taskPhase: nil, focusedRole: nil, modalClass: nil, navigationClass: nil, controlContext: nil)
        let worldState = WorldState(
            observationHash: "hash-1",
            planningState: planningState,
            observation: obs,
            repositorySnapshot: nil
        )
        let diff = StateDiffEngine.diff(current: model.snapshot, incoming: worldState)
        model.apply(diff: diff)

        #expect(model.snapshot.activeApplication == "TestApp")
        #expect(model.snapshot.windowTitle == "Window A")
        #expect(model.recentHistory(limit: 5).count == 1)
    }

    @Test("WorldStateModel history grows after sequential commits")
    func historyGrowsAfterCommits() {
        let model = WorldStateModel()
        for i in 1...3 {
            let obs = Observation(
                app: "App\(i)",
                windowTitle: "W\(i)",
                focusedElementID: "",
                elements: []
            )
            let planningState = PlanningState(id: PlanningStateID(rawValue: "state-\(i)"), clusterKey: StateClusterKey(rawValue: "c"), appID: "App\(i)", domain: nil, windowClass: nil, taskPhase: nil, focusedRole: nil, modalClass: nil, navigationClass: nil, controlContext: nil)
            let ws = WorldState(
                observationHash: "hash-\(i)",
                planningState: planningState,
                observation: obs,
                repositorySnapshot: nil
            )
            let diff = StateDiffEngine.diff(current: model.snapshot, incoming: ws)
            model.apply(diff: diff)
        }
        #expect(model.snapshot.activeApplication == "App3")
        #expect(model.recentHistory(limit: 10).count == 3)
    }

    @Test("StateDiffEngine produces empty diff when state is unchanged")
    func emptyDiffWhenUnchanged() {
        let model = WorldStateModel()
        let obs = Observation(app: "A", windowTitle: "T", focusedElementID: "", elements: [])
        let ps = PlanningState(id: PlanningStateID(rawValue: "s"), clusterKey: StateClusterKey(rawValue: "c"), appID: "A", domain: nil, windowClass: nil, taskPhase: nil, focusedRole: nil, modalClass: nil, navigationClass: nil, controlContext: nil)
        let ws = WorldState(observationHash: "h", planningState: ps, observation: obs, repositorySnapshot: nil)
        model.reset(from: ws)

        let diff = StateDiffEngine.diff(current: model.snapshot, incoming: ws)
        #expect(diff.isEmpty)
    }
}
"""
with open('/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/WorldModelAgentLoopWiringTests.swift', 'w') as f:
    f.write(content)
