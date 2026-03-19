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

    public init(runtime: AgentRuntime, planners: [any Planner]) {
        self.runtime = runtime
        self.planners = planners
    }

    @discardableResult
    public func run(goal: Goal) throws -> WorldState {
        let state = try runtime.currentState()
        let proposals = planners.map { $0.plan(goal: goal, state: state) }
        try detectConflicts(in: proposals)

        var finalState = state
        for planner in planners {
            finalState = try runtime.run(goal: goal, planner: planner)
        }
        return finalState
    }

    private func detectConflicts(in proposals: [[Command]]) throws {
        var seenPaths = Set<String>()
        var conflicts = Set<String>()

        for commandList in proposals {
            for command in commandList where command.type == "file.write" {
                let path = command.payload["path"] ?? ""
                if seenPaths.contains(path) {
                    conflicts.insert(path)
                } else {
                    seenPaths.insert(path)
                }
            }
        }

        if !conflicts.isEmpty {
            throw MultiAgentError.conflictingFileWrites(conflicts.sorted())
        }
    }
}
