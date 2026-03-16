import Foundation

// ─────────────────────────────────────────────────────────
// TaskGraphStore — bounded in-memory task graph with
//                  execution recording and diagnostics
//
// Wraps a TaskGraph with high-level operations for the
// runtime: state abstraction from context strings, verified
// execution recording, recovery edge queries, and DOT/JSON
// export for diagnostics.
//
// The TaskGraphStore is the single owner of the graph data
// for a given task session. The runtime calls it after each
// critic verdict to advance or record failures.
//
// ARCHITECTURE_RULES.md: protected backbone module.
// ─────────────────────────────────────────────────────────

public final class TaskGraphStore {

    public let graph: TaskGraph

    public init(
        maxNodesPerTask: Int = 200,
        maxEdgesPerNode: Int = 10
    ) {
        self.graph = TaskGraph(
            maxNodesPerTask: maxNodesPerTask,
            maxEdgesPerNode: maxEdgesPerNode
        )
    }

    // ── State abstraction ───────────────────────────────

    /// Derive an AbstractTaskState from a context string.
    /// Uses keyword matching on the context to classify the
    /// task-relevant state.
    public func abstractState(from context: String) -> AbstractTaskState {
        let lower = context.lowercased()

        // Modal / permission
        if lower.contains("permission") || lower.contains("auth") {
            return .permissionDialogActive
        }
        if lower.contains("modal") || lower.contains("dialog") {
            return .modalDialogActive
        }

        // Test lifecycle
        if lower.contains("test") && lower.contains("run") {
            return .testsRunning
        }
        if lower.contains("test") && lower.contains("pass") {
            return .testsPassed
        }
        if lower.contains("test") && lower.contains("fail") {
            return .failingTestIdentified
        }

        // Build lifecycle
        if lower.contains("build") && lower.contains("run") {
            return .buildRunning
        }
        if lower.contains("build") && lower.contains("success") {
            return .buildSucceeded
        }
        if lower.contains("build") && lower.contains("fail") {
            return .buildFailed
        }

        // Patch lifecycle
        if lower.contains("patch") && lower.contains("verify") {
            return .patchVerified
        }
        if lower.contains("patch") && lower.contains("reject") {
            return .patchRejected
        }
        if lower.contains("patch") && lower.contains("apply") {
            return .candidatePatchApplied
        }
        if lower.contains("patch") {
            return .candidatePatchGenerated
        }

        // Repository
        if lower.contains("index") && lower.contains("repo") {
            return .repoIndexed
        }
        if lower.contains("repo") || lower.contains("repository") {
            return .repoLoaded
        }

        // Browser / UI
        if lower.contains("login") {
            return .loginPageDetected
        }
        if lower.contains("navigate") || lower.contains("navigation") {
            return .navigationCompleted
        }
        if lower.contains("form") {
            return .formVisible
        }
        if lower.contains("page") || lower.contains("loaded") {
            return .pageLoaded
        }

        // General
        if lower.contains("recovery") || lower.contains("recover") {
            return .recoveryNeeded
        }
        if lower.contains("explore") || lower.contains("discovery") {
            return .explorationActive
        }
        if lower.contains("complete") || lower.contains("done") || lower.contains("goal reached") {
            return .goalReached
        }

        return .taskStarted
    }

    // ── High-level operations ───────────────────────────

    /// Create or update the current node from a context description.
    @discardableResult
    public func updateCurrentNode(
        context: String,
        createdByAction: String? = nil
    ) -> TaskNode {
        let abstract = abstractState(from: context)
        let node = TaskNode(
            abstractState: abstract,
            label: abstract.rawValue,
            createdByAction: createdByAction
        )
        let merged = graph.addOrMergeNode(node)
        graph.setCurrent(merged.id)
        return merged
    }

    /// Add a candidate edge from the current node to a projected future state.
    @discardableResult
    public func addCandidateEdge(
        action: String,
        domain: ActionDomain = .system,
        targetState: AbstractTaskState
    ) -> TaskEdge? {
        guard let fromID = graph.currentNodeID else { return nil }

        let toNode = graph.addOrMergeNode(TaskNode(
            abstractState: targetState,
            label: targetState.rawValue
        ))

        let edge = TaskEdge(
            fromNodeID: fromID,
            toNodeID: toNode.id,
            action: action,
            domain: domain
        )
        return graph.addEdge(edge)
    }

    /// After a verified execution, record the outcome and advance the graph.
    @discardableResult
    public func recordVerifiedExecution(
        edgeID: String,
        resultContext: String,
        latencyMs: Double = 0,
        cost: Double = 0,
        createdByAction: String? = nil
    ) -> TaskNode {
        let abstract = abstractState(from: resultContext)
        let resultNode = TaskNode(
            abstractState: abstract,
            label: abstract.rawValue,
            createdByAction: createdByAction
        )
        return graph.recordExecution(
            edgeID: edgeID,
            resultNode: resultNode,
            latencyMs: latencyMs,
            cost: cost
        )
    }

    /// Record a failed execution without advancing the current pointer.
    public func recordFailedExecution(
        edgeID: String,
        latencyMs: Double = 0,
        cost: Double = 0
    ) {
        graph.recordFailure(edgeID: edgeID, latencyMs: latencyMs, cost: cost)
    }

    // ── Query helpers ───────────────────────────────────

    /// The currently active node.
    public func currentNode() -> TaskNode? {
        return graph.currentNode()
    }

    /// Recovery alternatives: all non-abandoned edges from the current
    /// node excluding the one that just failed.
    public func recoveryEdges(excludingEdgeID: String) -> [TaskEdge] {
        guard let nodeID = graph.currentNodeID else { return [] }
        return graph.alternateEdges(from: nodeID, excluding: excludingEdgeID)
    }

    /// Viable next edges from the current node, ranked by success probability.
    public func viableNextEdges() -> [TaskEdge] {
        guard let nodeID = graph.currentNodeID else { return [] }
        return graph.viableEdges(from: nodeID)
            .sorted { $0.successProbability > $1.successProbability }
    }

    // ── Diagnostics ─────────────────────────────────────

    /// Export the graph in DOT format for visualization.
    public func exportDOT() -> String {
        var lines = ["digraph TaskGraph {"]
        lines.append("  rankdir=LR;")

        for node in graph.allNodes() {
            let label = "\(node.abstractState.rawValue)"
            let style = node.id == graph.currentNodeID
                ? " style=filled fillcolor=lightblue"
                : ""
            lines.append("  \"\(node.id.prefix(8))\" [label=\"\(label)\"\(style)];")
        }

        for edge in graph.allEdges() {
            let label = "\(edge.action)\\nP=\(String(format: "%.2f", edge.successProbability))"
            let color: String
            switch edge.status {
            case .executedSuccess: color = "green"
            case .executedFailure: color = "red"
            case .abandoned:       color = "gray"
            case .candidate:       color = "blue"
            }
            lines.append("  \"\(edge.fromNodeID.prefix(8))\" -> \"\(edge.toNodeID.prefix(8))\" [label=\"\(label)\" color=\(color)];")
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// Export the graph as a JSON-serialisable dictionary.
    public func exportJSON() -> [String: Any] {
        let nodeList = graph.allNodes().map { node -> [String: Any] in
            [
                "id": node.id,
                "abstractState": node.abstractState.rawValue,
                "visitCount": node.visitCount,
                "confidence": node.confidence,
                "isCurrent": node.id == graph.currentNodeID,
            ]
        }
        let edgeList = graph.allEdges().map { edge -> [String: Any] in
            [
                "id": edge.id,
                "from": edge.fromNodeID,
                "to": edge.toNodeID,
                "action": edge.action,
                "status": edge.status.rawValue,
                "successProbability": edge.successProbability,
                "attempts": edge.attempts,
            ]
        }
        return [
            "currentNodeID": graph.currentNodeID ?? "",
            "nodes": nodeList,
            "edges": edgeList,
        ]
    }

    /// Human-readable summary.
    public func summary() -> String {
        let currentLabel = graph.currentNode()?.abstractState.rawValue ?? "none"
        let totalEdges = graph.edgeCount
        let totalNodes = graph.nodeCount
        let totalAttempts = graph.allEdges().reduce(0) { $0 + $1.attempts }
        return """
        [taskGraph] Nodes: \(totalNodes), Edges: \(totalEdges)
        [taskGraph] Current: \(currentLabel)
        [taskGraph] Total edge attempts: \(totalAttempts)
        """
    }

    /// Reset the entire task graph.
    public func reset() {
        graph.reset()
    }
}
