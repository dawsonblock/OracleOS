import Foundation

public final class AgentLoop: Sendable {
    let planner: any Planner
    let resolver: CommandResolver
    let executor: VerifiedExecutor
    let store: any EventStore
    let reducer: any Reducer
    let critic: any Critic
    let repair: RepairEngine

    public init(
        planner: any Planner,
        resolver: CommandResolver,
        executor: VerifiedExecutor,
        store: any EventStore,
        reducer: any Reducer,
        critic: any Critic,
        repair: RepairEngine
    ) {
        self.planner = planner
        self.resolver = resolver
        self.executor = executor
        self.store = store
        self.reducer = reducer
        self.critic = critic
        self.repair = repair
    }

    public func execute(goal: Goal) async throws -> WorldState {
        let state = try ReplayEngine(store: store, reducer: reducer).rebuild()
        let commands = resolver.normalize(planner.plan(goal: goal, state: state))
        return try await execute(goal: goal, commands: commands)
    }

    func execute(goal: Goal, commands: [Command]) async throws -> WorldState {
        var state = try ReplayEngine(store: store, reducer: reducer).rebuild()
        var currentCommands = commands

        for _ in 0..<3 {
            var cycleEvents: [any DomainEvent] = []

            for command in currentCommands {
                let events = try executor.execute(command)
                try store.append(events)
                cycleEvents.append(contentsOf: events)
            }

            state = reducer.apply(cycleEvents, to: state)

            let evaluation = critic.evaluate(
                goal: goal,
                events: cycleEvents,
                state: state
            )

            if evaluation.success {
                return state
            }

            currentCommands = resolver.normalize(
                repair.proposeFixes(evaluation: evaluation)
            )
        }

        return state
    }

    public func currentState() throws -> WorldState {
        try ReplayEngine(store: store, reducer: reducer).rebuild()
    }

    public func recentEvents(limit: Int = 100) throws -> [EventEnvelope] {
        let events = try store.load()
        return Array(events.suffix(limit))
    }
}
