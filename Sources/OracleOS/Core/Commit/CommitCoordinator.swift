import Foundation

/// Coordinates the multi-stage commitment of observations and command results
/// to the durable store (WAL) and the in-memory world model.
public final class CommitCoordinator: Sendable {
    private let eventStore: DurableEventStore
    
    public init(eventStore: DurableEventStore = DurableEventStore()) {
        self.eventStore = eventStore
    }

    /// Records an atomic change to the system state.
    public func commit(
        change: StateChange,
        originatingCommandId: UUID? = nil
    ) async throws {
        let event = ExecutionEvent(
            id: UUID(),
            timestamp: Date(),
            type: .stateChanged,
            commandId: originatingCommandId,
            payload: [
                "change_type": change.type.rawValue,
                "entity_id": change.entityId
            ]
        )
        try eventStore.append(event: event)
        // In Phase 12+, this will interface with high-consistency storage (Raft).
    }
}

public struct StateChange: Sendable {
    public let entityId: String
    public let type: ChangeType
    public let data: [String: String]
    
    public enum ChangeType: String, Sendable {
        case created
        case updated
        case deleted
    }
}
