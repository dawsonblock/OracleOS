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

    public func currentState() throws -> WorldState {
        try loop.currentState()
    }

    public func recentEvents(limit: Int = 100) throws -> [EventEnvelope] {
        try loop.recentEvents(limit: limit)
    }
}
