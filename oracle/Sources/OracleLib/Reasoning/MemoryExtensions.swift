import Foundation

// MARK: - MemoryQueryContext + WorldState convenience initialiser

extension MemoryQueryContext {

    /// Create a `MemoryQueryContext` from a `TaskContext` and `WorldState`.
    public init(
        taskContext: TaskContext,
        worldState: WorldState,
        label: String? = nil,
        commandCategory: String? = nil,
        errorSignature: String? = nil,
        failureClass: FailureClass? = nil
    ) {
        self.init(
            agentKind: taskContext.agentKind,
            goalDescription: taskContext.goal.description,
            app: worldState.observation.app,
            windowTitle: worldState.observation.windowTitle,
            url: worldState.observation.url,
            domain: worldState.observation.url.flatMap { URL(string: $0)?.host },
            label: label,
            workspaceRoot: taskContext.workspaceRoot,
            commandCategory: commandCategory,
            errorSignature: errorSignature,
            failureClass: failureClass,
            repositorySnapshot: worldState.repositorySnapshot,
            planningState: worldState.planningState
        )
    }
}

// MARK: - MemoryRouter + workflowActionBias

extension MemoryRouter {

    /// Returns a bias score for an `ActionContract` based on execution/pattern memory.
    ///
    /// - Parameters:
    ///   - contract: The action contract being evaluated.
    ///   - app: The active application.
    ///   - goalDescription: The current goal description.
    ///   - workspaceRoot: The workspace root path.
    /// - Returns: A bias in [0, 0.3] that positively adjusts plan scores.
    public func workflowActionBias(
        contract: ActionContract,
        app: String?,
        goalDescription: String,
        workspaceRoot: String?
    ) -> Double {
        let execBias = rankingBias(
            label: contract.targetLabel,
            app: app,
            goalDescription: goalDescription
        )
        let cmdBias = commandBias(
            category: contract.commandCategory,
            workspaceRoot: workspaceRoot
        )
        return min(execBias + cmdBias, 0.3)
    }
}
