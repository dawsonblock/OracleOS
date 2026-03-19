import Foundation

public final class AgentLoop: Sendable {
    public let planner: any Planner
    public let resolver: CommandResolver
    public let executor: VerifiedExecutor
    public let store: any EventStore
    public let reducer: any Reducer
    public let critic: any Critic
    public let repair: RepairEngine
    public let maxIterations: Int

    public init(
        planner: any Planner,
        resolver: CommandResolver,
        executor: VerifiedExecutor,
        store: any EventStore,
        reducer: any Reducer,
        critic: any Critic,
        repair: RepairEngine,
        maxIterations: Int = 3
    ) {
        self.planner = planner
        self.resolver = resolver
        self.executor = executor
        self.store = store
        self.reducer = reducer
        self.critic = critic
        self.repair = repair
        self.maxIterations = maxIterations
    }

    public func run(goal: Goal) throws -> WorldState {
        try run(goal: goal, planner: planner)
    }

    public func run(goal: Goal, planner: any Planner) throws -> WorldState {
        var state = try currentState()
        var commands = resolver.normalize(planner.plan(goal: goal, state: state))

        guard !commands.isEmpty else {
            return state
        }

        for _ in 0..<maxIterations {
            var cycleEvents: [any DomainEvent] = []

            for command in commands {
                let events = try executor.execute(command)
                try store.append(events)
                cycleEvents.append(contentsOf: events)
            }

            state = reducer.apply(cycleEvents, to: state)
            let evaluation = critic.evaluate(goal: goal, events: cycleEvents, state: state)

            if evaluation.success {
                return state
            }

            commands = resolver.normalize(repair.proposeFixes(evaluation: evaluation))
            if commands.isEmpty {
                return state
            }
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
