import Foundation

/// Durable storage for execution events and world state changes.
/// This will eventually serve as the Write-Ahead Log (WAL) for the runtime.
public final class DurableEventStore: Sendable {
    private let storageURL: URL
    
    public init(storageURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("oracle_events.jsonl")) {
        self.storageURL = storageURL
    }

    /// Appends a new event to the store.
    public func append(event: ExecutionEvent) throws {
        let data = try JSONEncoder().encode(event)
        var lineData = data
        lineData.append(0x0A)
        try RuntimeFilesystem.append(lineData, to: storageURL)
    }
}

public struct ExecutionEvent: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: EventType
    public let commandId: UUID?
    public let payload: [String: String]
    
    public enum EventType: String, Codable {
        case commandIssued = "command_issued"
        case commandValidated = "command_validated"
        case commandExecuting = "command_executing"
        case commandCompleted = "command_completed"
        case stateChanged = "state_changed"
    }
}
