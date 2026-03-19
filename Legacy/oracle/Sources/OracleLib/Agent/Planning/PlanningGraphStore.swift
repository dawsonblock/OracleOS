import Foundation

public final class PlanningGraphStore {
    public let engine: PlanningGraphEngine

    public init(engine: PlanningGraphEngine = PlanningGraphEngine()) {
        self.engine = engine
    }

    @discardableResult
    public func addEdge(
        from sourceID: String,
        to targetID: String,
        actionType: String,
        domain: ActionDomain = .system
    ) -> PlanningEdge {
        engine.addEdge(from: sourceID, to: targetID, actionType: actionType, domain: domain)
    }

    public func recordTraversal(
        edgeID: String,
        success: Bool,
        cost: Double,
        latencyMs: Double
    ) {
        engine.recordTraversal(edgeID: edgeID, success: success, cost: cost, latencyMs: latencyMs)
    }

    public func findEdge(from sourceID: String, to targetID: String, actionType: String) -> PlanningEdge? {
        engine.findEdge(from: sourceID, to: targetID, actionType: actionType)
    }

    public func validActions(for stateID: String) -> [PlanningEdge] {
        engine.validActions(for: stateID)
    }
}