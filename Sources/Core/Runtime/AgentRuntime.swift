import Foundation

public final class AgentRuntime {
    private let loop: AgentLoop

    public init(loop: AgentLoop) {
        self.loop = loop
    }

    @discardableResult
    public func run(goal: Goal) async throws -> WorldState {
        try await loop.execute(goal: goal)
    }
}

public extension AgentRuntime {
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

    internal func run(goal: Goal, commands: [Command]) async throws -> WorldState {
        try await loop.execute(goal: goal, commands: commands)
    }
}
