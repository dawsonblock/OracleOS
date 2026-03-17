import Foundation

/// Coordinator for managing cluster membership and health.
/// Essential for Phase 11 (High Availability).
public final class ClusterCoordinator: Sendable {
    private let eventStore: DurableEventStore
    
    public init(eventStore: DurableEventStore = DurableEventStore()) {
        self.eventStore = eventStore
    }

    /// Transitions this node between Leader and Follower status.
    public func transition(to role: ClusterRole) async throws {
        // Log transition event
        try eventStore.append(event: ExecutionEvent(
            id: UUID(),
            timestamp: Date(),
            type: .stateChanged,
            commandId: nil,
            payload: ["cluster_role": role.rawValue]
        ))
    }
}

public enum ClusterRole: String, Codable, Sendable {
    case leader
    case follower
    case candidate
}
