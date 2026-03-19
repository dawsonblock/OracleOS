import Foundation

// MARK: - GraphStore + Reasoning layer bridge

/// Bridges the richer graph compatibility layer into lightweight `GraphEdge`
/// values used by the Reasoning planner.
extension GraphStore {

    /// Returns outgoing stable edges from a planning state.
    public func outgoingStableEdges(from stateID: PlanningStateID) -> [GraphEdge] {
        stableTransitions(from: stateID).map(\.reasoningEdge)
    }

    /// Returns outgoing candidate edges from a planning state.
    public func outgoingCandidateEdges(from stateID: PlanningStateID) -> [GraphEdge] {
        candidateTransitions(from: stateID).map(\.reasoningEdge)
    }
}
