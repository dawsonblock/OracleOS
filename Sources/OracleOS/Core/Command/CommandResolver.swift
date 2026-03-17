import Foundation

/// Resolves a PlannerDecision into a concrete ActionCommand by mapping
/// element queries to coordinates, validating state, and preparing the intent.
public final class CommandResolver: Sendable {
    private let stateAbstraction: StateAbstraction
    
    public init(stateAbstraction: StateAbstraction = StateAbstraction()) {
        self.stateAbstraction = stateAbstraction
    }

    /// Transforms a high-level PlannerDecision into an executable ActionCommand.
    public func resolve(
        decision: PlannerDecision,
        currentObservation: Observation,
        goal: Goal?
    ) async throws -> ActionCommand {
        // 1. Resolve Element Query (if any)
        var resolvedIntent = decision.actionContract.intent
        
        if let query = decision.semanticQuery {
            // Logic to find coordinates from observation based on query
            if let element = currentObservation.elements.first(where: { $0.label.contains(query.text) || $0.domID == query.domID }) {
                resolvedIntent.x = element.x
                resolvedIntent.y = element.y
                resolvedIntent.domID = element.domID
            }
        }
        
        // 2. Map Execution Mode
        let retryPolicy: ActionRetryPolicy = decision.executionMode == .experiment ? .simple(maxRetries: 2) : .none
        
        // 3. Construct Command
        return ActionCommand(
            goalId: goal?.id,
            actionType: .perception, // Map from decision.agentKind logic
            intent: resolvedIntent,
            timeout: 30.0,
            retryPolicy: retryPolicy,
            traceId: UUID().uuidString,
            metadata: [
                "planner_source": decision.source.rawValue,
                "planner_family": decision.plannerFamily.rawValue
            ]
        )
    }
}
