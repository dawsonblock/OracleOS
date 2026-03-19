import Core
import Foundation

public enum MultiAgentError: Error, LocalizedError, Sendable {
    case conflictingFileWrites([String])

    public var errorDescription: String? {
        switch self {
        case let .conflictingFileWrites(paths):
            return "Conflicting file.write commands detected: \(paths.joined(separator: ", "))"
        }
    }
}

public final class MultiAgentCoordinator: Sendable {
    private let runtime: AgentRuntime
    private let planners: [any Planner]
    private let resolver: CommandResolver

    public init(
        runtime: AgentRuntime,
        planners: [any Planner],
        resolver: CommandResolver = CommandResolver()
    ) {
        self.runtime = runtime
        self.planners = planners
        self.resolver = resolver
    }

    @discardableResult
    public func run(goal: Goal) throws -> WorldState {
        let state = try runtime.currentState()
        let proposals = plannedCommands(goal: goal, state: state)
        try detectConflicts(in: proposals)

        guard proposals.contains(where: { !$0.commands.isEmpty }) else {
            return state
        }

        var finalState = state
        for (plannerIndex, planner) in planners.enumerated() {
            guard !proposals[plannerIndex].commands.isEmpty else {
                continue
            }
            finalState = try runtime.run(goal: goal, planner: planner)
        }
        return finalState
    }

    public func plannedCommands(goal: Goal, state: WorldState) -> [PlannerCommandBatch] {
        planners.enumerated().map { index, planner in
            PlannerCommandBatch(
                plannerIndex: index,
                commands: resolver.normalize(planner.plan(goal: goal, state: state))
            )
        }
    }

    private func detectConflicts(in proposals: [PlannerCommandBatch]) throws {
        var seenPaths = [String: Int]()
        var conflicts = Set<String>()

        for proposal in proposals {
            for command in proposal.commands where command.type == "file.write" || command.type == "file.delete" {
                let path = command.payload["path"] ?? ""
                guard !path.isEmpty else {
                    continue
                }

                if let existingPlannerIndex = seenPaths[path], existingPlannerIndex != proposal.plannerIndex {
                    conflicts.insert(path)
                } else {
                    seenPaths[path] = proposal.plannerIndex
                }
            }
        }

        if !conflicts.isEmpty {
            throw MultiAgentError.conflictingFileWrites(conflicts.sorted())
        }
    }
}

public struct PlannerCommandBatch: Sendable, Equatable {
    public let plannerIndex: Int
    public let commands: [Command]

    public init(plannerIndex: Int, commands: [Command]) {
        self.plannerIndex = plannerIndex
        self.commands = commands
    }
}
