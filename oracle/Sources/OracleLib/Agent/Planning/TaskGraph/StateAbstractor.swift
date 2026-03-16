import Foundation

public struct StateAbstractor: Sendable {
    public init() {}

    public func abstractState(from worldState: WorldState) -> AbstractTaskState {
        let planning = worldState.planningState

        if let modalClass = planning.modalClass?.lowercased() {
            if modalClass.contains("permission") || modalClass.contains("auth") {
                return .permissionDialogActive
            }
            return .modalDialogActive
        }

        if let repo = worldState.repositorySnapshot {
            return codeAbstractState(planning: planning, repo: repo)
        }

        return uiAbstractState(planning: planning, observation: worldState.observation)
    }

    public func resolveNode(
        worldState: WorldState,
        taskGraph: TaskGraph,
        createdByAction: String? = nil
    ) -> TaskNode {
        let abstract = abstractState(from: worldState)
        let node = TaskNode(
            abstractState: abstract,
            label: abstract.rawValue,
            worldSnapshotRef: worldState.observation.stableHash(),
            createdByAction: createdByAction
        )
        return taskGraph.addOrMergeNode(node)
    }

    private func codeAbstractState(
        planning: PlanningState,
        repo: RepositorySnapshot
    ) -> AbstractTaskState {
        let phase = planning.taskPhase?.lowercased() ?? ""

        if phase.contains("test") && phase.contains("run") {
            return .testsRunning
        }
        if phase.contains("test") && phase.contains("pass") {
            return .testsPassed
        }
        if phase.contains("fail") && phase.contains("test") {
            return .failingTestIdentified
        }
        if phase.contains("build") && phase.contains("run") {
            return .buildRunning
        }
        if phase.contains("build") && phase.contains("success") {
            return .buildSucceeded
        }
        if phase.contains("build") && phase.contains("fail") {
            return .buildFailed
        }
        if phase.contains("patch") && phase.contains("apply") {
            return .candidatePatchApplied
        }
        if phase.contains("patch") && phase.contains("verif") {
            return .patchVerified
        }
        if phase.contains("patch") && phase.contains("reject") {
            return .patchRejected
        }
        if phase.contains("patch") {
            return .candidatePatchGenerated
        }
        if phase.contains("index") {
            return .repoIndexed
        }

        return repo.files.isEmpty ? .idle : .repoLoaded
    }

    private func uiAbstractState(
        planning: PlanningState,
        observation: Observation
    ) -> AbstractTaskState {
        let domain = planning.domain?.lowercased() ?? ""
        let phase = planning.taskPhase?.lowercased() ?? ""
        let app = planning.appID.lowercased()

        if domain.contains("login") || phase.contains("login") {
            return .loginPageDetected
        }
        if phase.contains("navigation") || phase.contains("navigate") {
            return .navigationCompleted
        }
        if phase.contains("form") {
            return .formVisible
        }
        if phase.contains("explore") || phase.contains("discovery") {
            return .explorationActive
        }
        if phase.contains("complete") || phase.contains("done") {
            return .goalReached
        }
        if phase.contains("recover") {
            return .recoveryNeeded
        }
        if !app.isEmpty || observation.app != nil {
            return .pageLoaded
        }
        return .idle
    }
}