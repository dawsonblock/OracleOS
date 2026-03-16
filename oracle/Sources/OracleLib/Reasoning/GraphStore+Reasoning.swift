import Foundation

// MARK: - GraphStore + Reasoning layer stubs

/// Provides stub implementations of graph query methods needed by the Reasoning layer.
/// Full graph query support is implemented in the Graph layer.
extension GraphStore {

    /// Returns outgoing stable edges from a planning state.
    /// Stub: returns empty array. Full implementation in the Graph layer.
    public func outgoingStableEdges(from stateID: PlanningStateID) -> [GraphEdge] { [] }

    /// Returns outgoing candidate edges from a planning state.
    /// Stub: returns empty array. Full implementation in the Graph layer.
    public func outgoingCandidateEdges(from stateID: PlanningStateID) -> [GraphEdge] { [] }

    /// Returns the `ActionContract` associated with a given contract ID.
    /// Stub: returns nil. Full implementation in the Graph layer.
    public func actionContract(for contractID: String) -> ActionContract? { nil }
}
