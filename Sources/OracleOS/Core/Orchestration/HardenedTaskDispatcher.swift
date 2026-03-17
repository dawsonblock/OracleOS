import Foundation

/// A hardened dispatcher that uses ActionCommand and ExecutionResult
/// for deterministic task routing across nodes.
public final class HardenedTaskDispatcher: Sendable {
    private let eventStore: DurableEventStore
    private let remoteProvider: RemoteExecutionProvider?
    
    public init(
        eventStore: DurableEventStore = DurableEventStore(),
        remoteProvider: RemoteExecutionProvider? = nil
    ) {
        self.eventStore = eventStore
        self.remoteProvider = remoteProvider
    }

    /// Dispatches a command to a specific node and tracks its lifecycle.
    public func dispatch(
        command: ActionCommand,
        targetNodeId: String
    ) async throws -> ExecutionResult {
        // 1. Log Dispatch Event
        try? eventStore.append(event: ExecutionEvent(
            id: UUID(),
            timestamp: Date(),
            type: .commandIssued,
            commandId: command.id,
            payload: ["target_node_id": targetNodeId]
        ))

        // 2. Handle Local vs Remote
        if targetNodeId == "local" {
            throw ExecutionError.localExecutionNotImplemented
        } else if let remote = remoteProvider {
            let result = try await remote.executeRemote(command: command, nodeId: targetNodeId)
            
            // 3. Log Completion
            try? eventStore.append(event: ExecutionEvent(
                id: UUID(),
                timestamp: Date(),
                type: .commandCompleted,
                commandId: command.id,
                payload: ["success": String(result.success)]
            ))
            
            return result
        } else {
            throw ExecutionError.noRemoteProvider
        }
    }
}

public enum ExecutionError: Error {
    case localExecutionNotImplemented
    case noRemoteProvider
}
