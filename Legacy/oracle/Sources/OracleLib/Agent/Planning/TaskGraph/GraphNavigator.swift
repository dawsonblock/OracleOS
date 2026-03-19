import Foundation

public struct GraphNavigator: Sendable {
    public let maxDepth: Int
    public let maxBranching: Int
    public let beamWidth: Int

    public init(maxDepth: Int = 3, maxBranching: Int = 5, beamWidth: Int = 4) {
        precondition(
            maxDepth >= 0 && maxBranching >= 0 && beamWidth >= 0,
            "GraphNavigator parameters must be non-negative."
        )
        self.maxDepth = maxDepth
        self.maxBranching = maxBranching
        self.beamWidth = beamWidth
    }

    public struct ScoredPath: @unchecked Sendable {
        public let edges: [TaskEdge]
        public let nodes: [TaskNode]
        public let cumulativeScore: Double
        public let terminalState: AbstractTaskState?
    }

    public func expand(
        from nodeID: String,
        in graph: TaskGraph,
        scorer: GraphScorer,
        goal: Goal? = nil,
        allowedFamilies: [OperatorFamily]
    ) -> [ScoredPath] {
        guard let startNode = graph.node(for: nodeID) else { return [] }

        var results: [ScoredPath] = []
        var visited: Set<String> = [nodeID]

        expandRecursive(
            currentNode: startNode,
            currentEdges: [],
            currentNodes: [startNode],
            cumulativeScore: 0,
            depth: 0,
            visited: &visited,
            graph: graph,
            scorer: scorer,
            goal: goal,
            allowedFamilies: allowedFamilies,
            results: &results
        )

        return Array(results.sorted { $0.cumulativeScore > $1.cumulativeScore }.prefix(max(beamWidth * max(maxDepth, 1), 1)))
    }

    public func bestNextEdge(
        from nodeID: String,
        in graph: TaskGraph,
        scorer: GraphScorer,
        goal: Goal? = nil,
        allowedFamilies: [OperatorFamily]
    ) -> TaskEdge? {
        expand(from: nodeID, in: graph, scorer: scorer, goal: goal, allowedFamilies: allowedFamilies).first?.edges.first
    }

    private func expandRecursive(
        currentNode: TaskNode,
        currentEdges: [TaskEdge],
        currentNodes: [TaskNode],
        cumulativeScore: Double,
        depth: Int,
        visited: inout Set<String>,
        graph: TaskGraph,
        scorer: GraphScorer,
        goal: Goal?,
        allowedFamilies: [OperatorFamily],
        results: inout [ScoredPath]
    ) {
        if !currentEdges.isEmpty {
            results.append(ScoredPath(
                edges: currentEdges,
                nodes: currentNodes,
                cumulativeScore: cumulativeScore,
                terminalState: currentNode.abstractState
            ))
        }

        guard depth < maxDepth else { return }

        var outgoing = graph.viableEdges(from: currentNode.id)
        outgoing = outgoing.filter { allowedFamilies.isEmpty || allowedFamilies.contains($0.operatorFamily) }

        let sorted = outgoing
            .sorted { scorer.scoreEdge($0) > scorer.scoreEdge($1) }
            .prefix(maxBranching)

        for edge in sorted {
            let toID = edge.toNodeID
            guard !visited.contains(toID), let toNode = graph.node(for: toID) else { continue }

            let edgeScore = scorer.scoreEdge(
                edge,
                goalState: goal.flatMap(GraphScorer.goalAbstractState),
                targetState: toNode.abstractState,
                allowedFamilies: allowedFamilies
            )

            visited.insert(toID)
            expandRecursive(
                currentNode: toNode,
                currentEdges: currentEdges + [edge],
                currentNodes: currentNodes + [toNode],
                cumulativeScore: cumulativeScore + edgeScore,
                depth: depth + 1,
                visited: &visited,
                graph: graph,
                scorer: scorer,
                goal: goal,
                allowedFamilies: allowedFamilies,
                results: &results
            )
            visited.remove(toID)
        }
    }

    public static func operatorFamilyForAction(_ action: String) -> OperatorFamily {
        let lowered = action.lowercased()
        if lowered.contains("test") || lowered.contains("build") || lowered.contains("compile") {
            return .repoAnalysis
        }
        if lowered.contains("patch") || lowered.contains("revert") || lowered.contains("rollback") {
            return .patchGeneration
        }
        if lowered.contains("experiment") {
            return .patchExperiment
        }
        if lowered.contains("browser") || lowered.contains("navigate") || lowered.contains("click") {
            return .browserTargeted
        }
        if lowered.contains("dismiss") || lowered.contains("retry") || lowered.contains("recovery") {
            return .recovery
        }
        if lowered.contains("open") || lowered.contains("focus") || lowered.contains("restart") {
            return .hostTargeted
        }
        if lowered.contains("permission") || lowered.contains("approve") {
            return .permissionHandling
        }
        if lowered.contains("workflow") {
            return .workflow
        }
        return .graphEdge
    }
}