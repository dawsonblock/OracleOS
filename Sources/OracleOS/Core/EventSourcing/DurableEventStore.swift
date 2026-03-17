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
        if let handle = try? FileHandle(forWritingTo: storageURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.write("\n".data(using: .utf8)!)
            handle.closeFile()
        } else {
            var lineData = data
            lineData.append("\n".data(using: .utf8)!)
            try lineData.write(to: storageURL)
        }
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
