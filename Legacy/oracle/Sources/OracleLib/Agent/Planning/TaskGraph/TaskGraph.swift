import Foundation

// ─────────────────────────────────────────────────────────
// TaskGraph — live task graph the planner navigates
//
// The canonical representation of the current task position.
// The planner operates on task graph nodes and edges, not
// on raw ephemeral state alone. Every verified action
// creates or updates a graph edge, and recovery branches
// through alternate edges rather than side channels.
//
// ARCHITECTURE_RULES.md: protected backbone module.
// ─────────────────────────────────────────────────────────

public final class TaskGraph {

    private var nodes: [String: TaskNode] = [:]
    private var edges: [String: TaskEdge] = [:]
    public private(set) var currentNodeID: String?

    // Growth limits
    public let maxNodesPerTask: Int
    public let maxEdgesPerNode: Int

    public init(
        maxNodesPerTask: Int = 200,
        maxEdgesPerNode: Int = 10
    ) {
        self.maxNodesPerTask = maxNodesPerTask
        self.maxEdgesPerNode = maxEdgesPerNode
    }

    // ── Node operations ─────────────────────────────────

    /// Add or merge a node. If a node with the same stateSignature
    /// exists, the existing node is returned (merged).
    @discardableResult
    public func addOrMergeNode(_ node: TaskNode) -> TaskNode {
        if let existing = findMergeCandidate(for: node) {
            existing.recordVisit()
            return existing
        }

        if nodes.count >= maxNodesPerTask {
            pruneOldestNodes()
            guard nodes.count < maxNodesPerTask else {
                // Return current or any existing node
                if let currentID = currentNodeID, let current = nodes[currentID] {
                    current.recordVisit()
                    return current
                }
                if let any = nodes.values.first {
                    any.recordVisit()
                    return any
                }
                return node
            }
        }

        node.recordVisit()
        nodes[node.id] = node
        return node
    }

    /// Lookup a node by ID.
    public func node(for id: String) -> TaskNode? {
        return nodes[id]
    }

    /// The currently active node.
    public func currentNode() -> TaskNode? {
        guard let id = currentNodeID else { return nil }
        return nodes[id]
    }

    /// Move the current position to a node.
    public func setCurrent(_ nodeID: String) {
        if nodes[nodeID] != nil {
            currentNodeID = nodeID
        }
    }

    public var nodeCount: Int { return nodes.count }

    public func allNodes() -> [TaskNode] {
        return Array(nodes.values)
    }

    // ── Edge operations ─────────────────────────────────

    /// Add a candidate or executed edge.
    @discardableResult
    public func addEdge(_ edge: TaskEdge) -> TaskEdge {
        // Enforce per-node edge cap
        let fromEdges = outgoingEdges(from: edge.fromNodeID)
        if fromEdges.count >= maxEdgesPerNode {
            pruneWeakestEdges(from: edge.fromNodeID)
        }

        edges[edge.id] = edge
        return edge
    }

    /// Lookup an edge by ID.
    public func edge(for id: String) -> TaskEdge? {
        return edges[id]
    }

    /// All outgoing edges from a node.
    public func outgoingEdges(from nodeID: String) -> [TaskEdge] {
        return edges.values.filter { $0.fromNodeID == nodeID }
    }

    /// Viable (non-failed, non-abandoned) outgoing edges.
    public func viableEdges(from nodeID: String) -> [TaskEdge] {
        return outgoingEdges(from: nodeID).filter {
            $0.status != .executedFailure && $0.status != .abandoned
        }
    }

    /// Alternate edges from the same source, excluding a specific edge.
    /// Used for recovery branching.
    public func alternateEdges(from nodeID: String, excluding edgeID: String) -> [TaskEdge] {
        return outgoingEdges(from: nodeID).filter {
            $0.id != edgeID && $0.status != .abandoned
        }
    }

    public var edgeCount: Int { return edges.count }

    public func allEdges() -> [TaskEdge] {
        return Array(edges.values)
    }

    // ── Graph update cycle ──────────────────────────────

    /// Record a successful execution: update edge evidence, create the
    /// destination node if needed, and advance the current pointer.
    @discardableResult
    public func recordExecution(
        edgeID: String,
        resultNode: TaskNode,
        latencyMs: Double = 0,
        cost: Double = 0
    ) -> TaskNode {
        let destination = addOrMergeNode(resultNode)

        guard let edge = edges[edgeID] else {
            return destination
        }

        edge.recordSuccess(latencyMs: latencyMs, cost: cost)
        currentNodeID = destination.id
        return destination
    }

    /// Record a failed execution: mark the edge, do NOT advance
    /// the current pointer. The planner can select an alternate edge.
    public func recordFailure(edgeID: String, latencyMs: Double = 0, cost: Double = 0) {
        if let edge = edges[edgeID] {
            edge.recordFailure(latencyMs: latencyMs, cost: cost)
        }
    }

    // ── Merge / Prune helpers ───────────────────────────

    private func findMergeCandidate(for node: TaskNode) -> TaskNode? {
        for existing in nodes.values {
            if existing.stateSignature == node.stateSignature {
                return existing
            }
        }
        return nil
    }

    private func pruneOldestNodes() {
        let sorted = nodes.values.sorted { $0.timestamp < $1.timestamp }
        let toRemove = sorted.prefix(max(1, nodes.count / 10))
        for node in toRemove {
            guard node.id != currentNodeID else { continue }
            removeNode(node.id)
        }
    }

    private func pruneWeakestEdges(from nodeID: String) {
        let fromEdges = edges.values
            .filter { $0.fromNodeID == nodeID }
            .sorted { $0.successProbability < $1.successProbability }
        let toRemove = fromEdges.prefix(max(1, fromEdges.count / 4))
        for edge in toRemove {
            edges.removeValue(forKey: edge.id)
        }
    }

    private func removeNode(_ nodeID: String) {
        nodes.removeValue(forKey: nodeID)
        let orphaned = edges.values.filter {
            $0.fromNodeID == nodeID || $0.toNodeID == nodeID
        }
        for edge in orphaned {
            edges.removeValue(forKey: edge.id)
        }
    }

    /// Reset the entire graph.
    public func reset() {
        nodes.removeAll()
        edges.removeAll()
        currentNodeID = nil
    }
}
