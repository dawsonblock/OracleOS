import Foundation

final class GraphCompatibilityStorage: @unchecked Sendable {
    let lock = NSRecursiveLock()
    let candidateGraph = CandidateGraph()
    let stableGraph = StableGraph()
    let maintenance = GraphMaintenance()
    var planningStates: [PlanningStateID: PlanningState] = [:]
    var actionContracts: [String: ActionContract] = [:]
}

extension GraphStore {

    private var graphStorage: GraphCompatibilityStorage {
        compatibilityStorage
    }

    public func recordTransition(
        _ transition: VerifiedTransition,
        actionContract: ActionContract? = nil,
        fromState: PlanningState? = nil,
        toState: PlanningState? = nil
    ) {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }

        let governedTransition = sanitize(transition)
        if let fromState {
            storage.planningStates[fromState.id] = fromState
        }
        if let toState {
            storage.planningStates[toState.id] = toState
        }
        if let actionContract {
            storage.actionContracts[actionContract.id] = actionContract
        }

        storage.candidateGraph.record(governedTransition)
    }

    public func recordFailure(
        state: PlanningState,
        actionContract: ActionContract,
        failure: FailureClass,
        ambiguityScore: Double? = nil,
        recoveryTagged: Bool = false
    ) {
        let transition = VerifiedTransition(
            fromPlanningStateID: state.id,
            toPlanningStateID: state.id,
            actionContractID: actionContract.id,
            agentKind: actionContract.agentKind,
            domain: actionContract.domain,
            workspaceRelativePath: actionContract.workspaceRelativePath,
            commandCategory: actionContract.commandCategory,
            plannerFamily: actionContract.plannerFamily,
            postconditionClass: .actionFailed,
            verified: false,
            failureClass: failure.rawValue,
            latencyMs: 0,
            targetAmbiguityScore: ambiguityScore,
            recoveryTagged: recoveryTagged,
            approvalRequired: false,
            approvalOutcome: nil,
            knowledgeTier: recoveryTagged ? .recovery : .candidate
        )

        recordTransition(transition, actionContract: actionContract, fromState: state, toState: state)
    }

    @discardableResult
    public func promoteEligibleEdges(now: Date = Date()) -> [EdgeTransition] {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }

        return storage.maintenance.promoteEligibleEdges(
            candidateGraph: storage.candidateGraph,
            stableGraph: storage.stableGraph,
            globalVerifiedSuccessRate: globalSuccessRate(),
            now: now
        )
    }

    @discardableResult
    public func pruneOrDemoteEdges(now: Date = Date()) -> [String] {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }

        return storage.maintenance.pruneOrDemoteEdges(
            candidateGraph: storage.candidateGraph,
            stableGraph: storage.stableGraph,
            now: now
        )
    }

    public func promoteStableGraph() {
        _ = promoteEligibleEdges()
    }

    public func stableTransitions(from planningStateID: PlanningStateID) -> [EdgeTransition] {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.stableGraph.outgoing(from: planningStateID)
    }

    public func candidateTransitions(from planningStateID: PlanningStateID) -> [EdgeTransition] {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }

        return storage.candidateGraph.edges.values
            .filter {
                $0.fromPlanningStateID == planningStateID
                    && $0.knowledgeTier == .candidate
                    && $0.successes > 0
            }
            .sorted { $0.cost < $1.cost }
    }

    public func actionContract(for id: String) -> ActionContract? {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.actionContracts[id]
    }

    public func planningState(for id: PlanningStateID) -> PlanningState? {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.planningStates[id]
    }

    public func stableEdge(for id: String) -> EdgeTransition? {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.stableGraph.edges[id]
    }

    public func allStableEdges() -> [EdgeTransition] {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.stableGraph.edges.values.sorted { $0.edgeID < $1.edgeID }
    }

    public func allCandidateEdges() -> [EdgeTransition] {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.candidateGraph.edges.values.sorted { $0.edgeID < $1.edgeID }
    }

    public func globalSuccessRate() -> Double {
        let stats = globalStats()
        guard stats.attempts > 0 else { return 0 }
        return Double(stats.successes) / Double(stats.attempts)
    }

    public static func defaultDatabaseURL() -> URL {
        OracleProductPaths.graphDatabaseURL
    }

    private func sanitize(_ transition: VerifiedTransition) -> VerifiedTransition {
        var governedTier = transition.knowledgeTier

        if transition.recoveryTagged {
            governedTier = .recovery
        } else if transition.knowledgeTier == .stable {
            governedTier = .candidate
        }

        guard governedTier != transition.knowledgeTier else {
            return transition
        }

        return VerifiedTransition(
            fromPlanningStateID: transition.fromPlanningStateID,
            toPlanningStateID: transition.toPlanningStateID,
            actionContractID: transition.actionContractID,
            agentKind: transition.agentKind,
            domain: transition.domain,
            workspaceRelativePath: transition.workspaceRelativePath,
            commandCategory: transition.commandCategory,
            plannerFamily: transition.plannerFamily,
            postconditionClass: transition.postconditionClass,
            verified: transition.verified,
            failureClass: transition.failureClass,
            latencyMs: transition.latencyMs,
            targetAmbiguityScore: transition.targetAmbiguityScore,
            recoveryTagged: transition.recoveryTagged,
            approvalRequired: transition.approvalRequired,
            approvalOutcome: transition.approvalOutcome,
            knowledgeTier: governedTier,
            timestamp: transition.timestamp
        )
    }

    private func globalStats() -> GraphStats {
        let storage = graphStorage
        storage.lock.lock()
        defer { storage.lock.unlock() }

        let attempts = storage.candidateGraph.edges.values.reduce(0) { $0 + $1.attempts }
        let successes = storage.candidateGraph.edges.values.reduce(0) { $0 + $1.successes }
        return GraphStats(attempts: attempts, successes: successes, updatedAt: Date().timeIntervalSince1970)
    }
}