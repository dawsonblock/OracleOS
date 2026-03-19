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
        try runResult(goal: goal, planner: planner).state
    }

    public func run(goal: Goal, planner: any Planner) throws -> WorldState {
        try runResult(goal: goal, planner: planner).state
    }

    public func runResult(goal: Goal) throws -> RuntimeRunResult {
        try runResult(goal: goal, planner: planner)
    }

    public func runResult(goal: Goal, planner: any Planner) throws -> RuntimeRunResult {
        try execute(goal: goal) { state in
            resolver.normalize(planner.plan(goal: goal, state: state))
        }
    }

    public func runResult(goal: Goal, commands: [Command]) throws -> RuntimeRunResult {
        let normalizedCommands = resolver.normalize(commands)
        return try execute(goal: goal) { _ in normalizedCommands }
    }

    public func currentState() throws -> WorldState {
        try ReplayEngine(store: store, reducer: reducer).rebuild()
    }

    public func recentEvents(limit: Int = 100) throws -> [EventEnvelope] {
        let events = try store.load()
        return Array(events.suffix(limit))
    }

    private func isTimeoutError(_ error: Error) -> Bool {
        if let runtimeError = error as? RuntimeError,
           case .executionTimedOut = runtimeError {
            return true
        }
        return false
    }

    private func execute(
        goal: Goal,
        commandProvider: (WorldState) -> [Command]
    ) throws -> RuntimeRunResult {
        var state = try currentState()
        var commands = commandProvider(state)
        var emittedEventCount = 0

        guard !commands.isEmpty else {
            return RuntimeRunResult(state: state, success: false, issues: ["Planner returned no commands."], emittedEventCount: 0)
        }

        for _ in 0..<maxIterations {
            var cycleEvents: [any DomainEvent] = []

            for command in commands {
                let events: [any DomainEvent]
                do {
                    events = try executor.execute(command)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                    events = [
                        CommandFailedEvent(
                            commandID: command.id,
                            commandType: command.type,
                            reason: message,
                            timedOut: isTimeoutError(error)
                        ),
                    ]
                }
                try store.append(events)
                cycleEvents.append(contentsOf: events)
            }

            emittedEventCount += cycleEvents.count
            state = reducer.apply(cycleEvents, to: state)
            let evaluation = critic.evaluate(goal: goal, events: cycleEvents, state: state)

            if evaluation.success {
                return RuntimeRunResult(
                    state: state,
                    success: true,
                    issues: [],
                    emittedEventCount: emittedEventCount
                )
            }

            commands = resolver.normalize(repair.proposeFixes(evaluation: evaluation))
            if commands.isEmpty {
                return RuntimeRunResult(
                    state: state,
                    success: false,
                    issues: evaluation.issues,
                    emittedEventCount: emittedEventCount
                )
            }
        }

        let finalEvaluation = critic.evaluate(goal: goal, events: [], state: state)
        return RuntimeRunResult(
            state: state,
            success: finalEvaluation.success,
            issues: finalEvaluation.issues,
            emittedEventCount: emittedEventCount
        )
    }
}
