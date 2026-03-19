import Foundation

/// Strategy for planning decisions.
public protocol PlanningStrategy: Sendable {
    func decide(
        goal: Goal,
        worldState: WorldState,
        history: [ExecutionResult]
    ) async throws -> PlannerDecision?
}

/// A deterministic strategy that follows a predefined graph or workflow.
public final class DeterministicStrategy: PlanningStrategy {
    public init() {}
    
    public func decide(
        goal: Goal,
        worldState: WorldState,
        history: [ExecutionResult]
    ) async throws -> PlannerDecision? {
        // Implementation for walking the graph deterministically
        return nil // Placeholder
    }
}

/// An LLM-backed strategy for open-ended exploration.
public final class ExplorationStrategy: PlanningStrategy {
    public init() {}
    
    public func decide(
        goal: Goal,
        worldState: WorldState,
        history: [ExecutionResult]
    ) async throws -> PlannerDecision? {
        // Implementation for calling LLM to generate PlannerDecision
        return nil // Placeholder
    }
}
