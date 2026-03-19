import Core
import Foundation

public enum MultiAgentError: Error, LocalizedError, Sendable {
    case conflictingFileCommands([String])

    public var errorDescription: String? {
        switch self {
        case let .conflictingFileCommands(paths):
            return "Conflicting file commands detected: \(paths.joined(separator: ", "))"
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
        var state = try runtime.currentState()
        var reservedPaths = [String: Int]()

        for (plannerIndex, planner) in planners.enumerated() {
            let commands = resolver.normalize(planner.plan(goal: goal, state: state))
            try detectConflicts(
                commands: commands,
                plannerIndex: plannerIndex,
                reservedPaths: &reservedPaths
            )

            guard !commands.isEmpty else {
                continue
            }

            state = try runtime.runResult(goal: goal, commands: commands).state
        }
        return state
    }

    public func plannedCommands(goal: Goal, state: WorldState) -> [PlannerCommandBatch] {
        planners.enumerated().map { index, planner in
            PlannerCommandBatch(
                plannerIndex: index,
                commands: resolver.normalize(planner.plan(goal: goal, state: state))
            )
        }
    }

    private func detectConflicts(
        commands: [Command],
        plannerIndex: Int,
        reservedPaths: inout [String: Int]
    ) throws {
        var conflicts = Set<String>()

        for command in commands where command.type == "file.write" || command.type == "file.delete" {
            let path = command.payload["path"] ?? ""
            guard !path.isEmpty else {
                continue
            }

            if let existingPlannerIndex = reservedPaths[path], existingPlannerIndex != plannerIndex {
                conflicts.insert(path)
            } else {
                reservedPaths[path] = plannerIndex
            }
        }

        if !conflicts.isEmpty {
            throw MultiAgentError.conflictingFileCommands(conflicts.sorted())
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
