import Foundation

public final class AgentRuntime: Sendable {
    private let loop: AgentLoop

    public init(loop: AgentLoop) {
        self.loop = loop
    }

    @discardableResult
    public func run(goal: Goal) throws -> WorldState {
        try loop.run(goal: goal)
    }

    @discardableResult
    public func run(goal: Goal, planner: any Planner) throws -> WorldState {
        try loop.run(goal: goal, planner: planner)
    }

    public func runResult(goal: Goal) throws -> RuntimeRunResult {
        try loop.runResult(goal: goal)
    }

    public func runResult(goal: Goal, planner: any Planner) throws -> RuntimeRunResult {
        try loop.runResult(goal: goal, planner: planner)
    }

    public func runResult(goal: Goal, commands: [Command]) throws -> RuntimeRunResult {
        try loop.runResult(goal: goal, commands: commands)
    }

    public func currentState() throws -> WorldState {
        try loop.currentState()
    }

    public func currentStateSummary() throws -> RuntimeStateSummary {
        try RuntimeViewBuilder.stateSummary(from: currentState())
    }

    public func recentEvents(limit: Int = 100) throws -> [EventEnvelope] {
        try loop.recentEvents(limit: limit)
    }

    public func recentEventSummaries(limit: Int = 100) throws -> [RuntimeEventSummary] {
        try RuntimeViewBuilder.eventSummaries(from: recentEvents(limit: limit))
    }
}
