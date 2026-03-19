import Foundation

@MainActor
public final class AgentRuntime {
    public let planner: Planner
    public let executor: VerifiedExecutor
    public let coordinator: CommitCoordinator
    public let reducer: any Reducer
    public let critic: any Critic
    public let repair: RepairEngine

    public init(
        planner: Planner = Planner(),
        executor: VerifiedExecutor = VerifiedExecutor(),
        coordinator: CommitCoordinator = CommitCoordinator(),
        reducer: any Reducer = DefaultReducer(),
        critic: any Critic = BasicCritic(),
        repair: RepairEngine = RepairEngine()
    ) {
        self.planner = planner
        self.executor = executor
        self.coordinator = coordinator
        self.reducer = reducer
        self.critic = critic
        self.repair = repair
    }

    @discardableResult
    public func run(goal: Goal) async -> WorldState {
        var state = WorldState.empty
        var commands = planner.plan(goal: goal, state: state)

        for _ in 0..<3 {
            var allEvents: [any DomainEvent] = []

            for command in commands {
                let events = (try? executor.execute(command)) ?? []
                coordinator.commit(events)
                allEvents.append(contentsOf: events)
            }

            state = reducer.apply(allEvents, to: state)
            let evaluation = critic.evaluate(goal: goal, events: allEvents, state: state)

            if evaluation.success {
                return state
            }

            commands = repair.proposeFixes(evaluation: evaluation)
            if commands.isEmpty {
                return state
            }
        }

        return state
    }
}
