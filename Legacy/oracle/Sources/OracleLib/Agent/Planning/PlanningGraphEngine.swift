import Foundation

// ─────────────────────────────────────────────────────────
// PlanningGraphEngine — finite action graph for planning
//
// Stores allowed state transitions as a graph of edges.
// Each edge connects two abstract task states via a concrete
// action type. The planner should operate over this graph
// rather than generating arbitrary step sequences.
//
// Edge scoring: score = successRate − costWeight − latencyWeight
// Weak edges are pruned when success rate drops below threshold.
// Traversal outcomes update edge statistics.
//
// Protected backbone module per ARCHITECTURE_RULES.md.
// ─────────────────────────────────────────────────────────

/// A node in the planning graph representing an abstract task state.
public struct PlanningNode: Hashable {

    public let id: String
    public let label: String

    public init(id: String = UUID().uuidString, label: String) {
        self.id = id
        self.label = label
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: PlanningNode, rhs: PlanningNode) -> Bool {
        return lhs.id == rhs.id
    }
}

/// An edge in the planning graph connecting two states via an action.
public struct PlanningEdge {

    public let id: String
    public let sourceID: String
    public let targetID: String
    public let actionType: String
    public let domain: ActionDomain

    // ── Statistics ───────────────────────────────────────

    public private(set) var traversals: Int
    public private(set) var successes: Int
    public private(set) var totalCost: Double
    public private(set) var totalLatencyMs: Double
    public let createdAt: Date

    public init(
        sourceID: String,
        targetID: String,
        actionType: String,
        domain: ActionDomain = .system
    ) {
        self.id = UUID().uuidString
        self.sourceID = sourceID
        self.targetID = targetID
        self.actionType = actionType
        self.domain = domain
        self.traversals = 0
        self.successes = 0
        self.totalCost = 0
        self.totalLatencyMs = 0
        self.createdAt = Date()
    }

    // ── Derived metrics ─────────────────────────────────

    public var successRate: Double {
        guard traversals > 0 else { return 0 }
        return Double(successes) / Double(traversals)
    }

    public var averageCost: Double {
        guard traversals > 0 else { return 0 }
        return totalCost / Double(traversals)
    }

    public var averageLatencyMs: Double {
        guard traversals > 0 else { return 0 }
        return totalLatencyMs / Double(traversals)
    }

    /// Composite score: higher is better.
    /// score = successRate − (costWeight * avgCost) − (latencyWeight * avgLatency)
    public var score: Double {
        let costPenalty = 0.01 * averageCost
        let latencyPenalty = 0.001 * averageLatencyMs
        return successRate - costPenalty - latencyPenalty
    }

    // ── Mutation (value-type copy-on-write) ─────────────

    public mutating func recordTraversal(success: Bool, cost: Double, latencyMs: Double) {
        traversals += 1
        if success { successes += 1 }
        totalCost += cost
        totalLatencyMs += latencyMs
    }
}

/// PlanningGraphEngine manages the finite action graph.
public final class PlanningGraphEngine {

    // ── Configuration ───────────────────────────────────

    /// Minimum success rate before an edge is pruned
    public static let pruneThreshold: Double = 0.15

    /// Minimum traversals before pruning is eligible
    public static let minTraversalsForPrune: Int = 3

    /// Maximum edges per source node
    public static let maxEdgesPerNode: Int = 20

    /// Maximum total nodes
    public static let maxNodes: Int = 200

    // ── Storage ─────────────────────────────────────────

    private var nodes: [String: PlanningNode] = [:]
    private var edges: [String: PlanningEdge] = [:]

    /// Adjacency list: sourceID → [edgeID]
    private var adjacency: [String: [String]] = [:]

    public init() {}

    // ── Node management ─────────────────────────────────

    /// Register a node. Returns the node (existing or new).
    @discardableResult
    public func addNode(_ node: PlanningNode) -> PlanningNode {
        if let existing = nodes[node.id] { return existing }

        // Enforce capacity
        if nodes.count >= PlanningGraphEngine.maxNodes {
            evictWeakestNode()
        }

        nodes[node.id] = node
        if adjacency[node.id] == nil {
            adjacency[node.id] = []
        }
        return node
    }

    /// Lookup a node by ID.
    public func node(id: String) -> PlanningNode? {
        return nodes[id]
    }

    /// All registered nodes.
    public var allNodes: [PlanningNode] {
        return Array(nodes.values)
    }

    public var nodeCount: Int { return nodes.count }

    // ── Edge management ─────────────────────────────────

    /// Add an edge between two nodes. Registers nodes if needed.
    @discardableResult
    public func addEdge(
        from sourceID: String,
        to targetID: String,
        actionType: String,
        domain: ActionDomain = .system
    ) -> PlanningEdge {
        // Ensure nodes exist
        if nodes[sourceID] == nil {
            addNode(PlanningNode(id: sourceID, label: sourceID))
        }
        if nodes[targetID] == nil {
            addNode(PlanningNode(id: targetID, label: targetID))
        }

        // Check for duplicate edge (same source, target, action)
        if let existingID = adjacency[sourceID]?.first(where: { edgeID in
            guard let e = edges[edgeID] else { return false }
            return e.targetID == targetID && e.actionType == actionType
        }) {
            return edges[existingID]!
        }

        // Enforce per-node edge cap
        if let count = adjacency[sourceID]?.count,
           count >= PlanningGraphEngine.maxEdgesPerNode {
            pruneWeakestEdge(from: sourceID)
        }

        let edge = PlanningEdge(
            sourceID: sourceID,
            targetID: targetID,
            actionType: actionType,
            domain: domain
        )

        edges[edge.id] = edge
        adjacency[sourceID, default: []].append(edge.id)
        return edge
    }

    /// Record the outcome of traversing an edge.
    public func recordTraversal(
        edgeID: String,
        success: Bool,
        cost: Double = 1.0,
        latencyMs: Double = 0
    ) {
        guard var edge = edges[edgeID] else { return }
        edge.recordTraversal(success: success, cost: cost, latencyMs: latencyMs)
        edges[edgeID] = edge
    }

    /// Find an edge by source, target, and action type.
    public func findEdge(
        from sourceID: String,
        to targetID: String,
        actionType: String
    ) -> PlanningEdge? {
        guard let edgeIDs = adjacency[sourceID] else { return nil }
        for edgeID in edgeIDs {
            if let e = edges[edgeID],
               e.targetID == targetID,
               e.actionType == actionType {
                return e
            }
        }
        return nil
    }

    public var edgeCount: Int { return edges.count }

    // ── Queries ─────────────────────────────────────────

    /// Valid actions from a given state, ranked by score descending.
    public func validActions(for stateID: String) -> [PlanningEdge] {
        guard let edgeIDs = adjacency[stateID] else { return [] }
        return edgeIDs
            .compactMap { edges[$0] }
            .sorted { $0.score > $1.score }
    }

    /// Top-ranked action from a state. Returns nil if none available.
    public func bestAction(for stateID: String) -> PlanningEdge? {
        return validActions(for: stateID).first
    }

    /// All edges (unordered).
    public var allEdges: [PlanningEdge] {
        return Array(edges.values)
    }

    /// Edges targeting a specific node.
    public func incomingEdges(for targetID: String) -> [PlanningEdge] {
        return edges.values.filter { $0.targetID == targetID }
    }

    // ── Pruning ─────────────────────────────────────────

    /// Remove weak edges below the success threshold.
    /// Returns count of pruned edges.
    @discardableResult
    public func pruneWeakEdges() -> Int {
        var pruned = 0
        let candidates = edges.values.filter {
            $0.traversals >= PlanningGraphEngine.minTraversalsForPrune
            && $0.successRate < PlanningGraphEngine.pruneThreshold
        }

        for edge in candidates {
            removeEdge(id: edge.id)
            pruned += 1
        }

        if pruned > 0 {
            print("[planGraph] Pruned \(pruned) weak edges")
        }
        return pruned
    }

    /// Prune the weakest edge from a specific source node.
    private func pruneWeakestEdge(from sourceID: String) {
        guard let edgeIDs = adjacency[sourceID],
              let weakestID = edgeIDs
                .compactMap({ edges[$0] })
                .sorted(by: { $0.score < $1.score })
                .first?.id else { return }
        removeEdge(id: weakestID)
    }

    /// Evict the node with fewest total edge traversals.
    private func evictWeakestNode() {
        let scored = nodes.keys.map { nodeID -> (String, Int) in
            let outTraversals = (adjacency[nodeID] ?? [])
                .compactMap { edges[$0]?.traversals }
                .reduce(0, +)
            let inTraversals = edges.values
                .filter { $0.targetID == nodeID }
                .map { $0.traversals }
                .reduce(0, +)
            return (nodeID, outTraversals + inTraversals)
        }
        guard let weakest = scored.min(by: { $0.1 < $1.1 }) else { return }
        removeNode(id: weakest.0)
    }

    /// Remove a single edge.
    private func removeEdge(id: String) {
        guard let edge = edges.removeValue(forKey: id) else { return }
        adjacency[edge.sourceID]?.removeAll { $0 == id }
    }

    /// Remove a node and all connected edges.
    private func removeNode(id: String) {
        // Remove outgoing edges
        if let outEdgeIDs = adjacency.removeValue(forKey: id) {
            for eid in outEdgeIDs { edges.removeValue(forKey: eid) }
        }
        // Remove incoming edges
        let incoming = edges.filter { $0.value.targetID == id }
        for (eid, edge) in incoming {
            edges.removeValue(forKey: eid)
            adjacency[edge.sourceID]?.removeAll { $0 == eid }
        }
        nodes.removeValue(forKey: id)
    }

    // ── Diagnostics ─────────────────────────────────────

    /// Export the graph in DOT format for visualization.
    public func exportDOT() -> String {
        var dot = "digraph PlanningGraph {\n"
        dot += "  rankdir=LR;\n"

        for node in nodes.values {
            dot += "  \"\(node.id)\" [label=\"\(node.label)\"];\n"
        }

        for edge in edges.values {
            let label = "\(edge.actionType)\\n\(String(format: "%.0f%%", edge.successRate * 100))"
            dot += "  \"\(edge.sourceID)\" -> \"\(edge.targetID)\" [label=\"\(label)\"];\n"
        }

        dot += "}\n"
        return dot
    }

    /// Human-readable summary.
    public func summary() -> String {
        let totalTraversals = edges.values.reduce(0) { $0 + $1.traversals }
        let avgScore = edges.isEmpty ? 0 :
            edges.values.reduce(0.0) { $0 + $1.score } / Double(edges.count)
        return """
        [planGraph] Nodes: \(nodes.count), Edges: \(edges.count)
        [planGraph] Total traversals: \(totalTraversals)
        [planGraph] Avg edge score: \(String(format: "%.3f", avgScore))
        """
    }

    /// Reset the entire graph.
    public func reset() {
        nodes.removeAll()
        edges.removeAll()
        adjacency.removeAll()
    }
}
