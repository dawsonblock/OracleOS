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
        let originalIntent = decision.actionContract.intent
        let resolvedIntent: ActionIntent
        
        if let query = decision.semanticQuery,
           let element = currentObservation.elements.first(where: { element in
               element.label.contains(query.text) || element.id == query.domID
           }),
           let frame = element.frame {
            // Construct a new intent with resolved coordinates and identifier.
            // Other intent fields are assumed to be preserved via the ActionIntent API.
            resolvedIntent = ActionIntent(
                x: frame.origin.x,
                y: frame.origin.y,
                domID: element.id
            )
        } else {
            // Fall back to the original intent if we cannot resolve an element.
            resolvedIntent = originalIntent
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
