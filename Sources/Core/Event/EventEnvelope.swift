import Foundation

public struct EventEnvelope: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let commandID: UUID
    public let type: String
    public let event: Data

    public init(
        id: UUID,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        commandID: UUID,
        type: String,
        event: Data
    ) {
        self.id = id
        self.timestamp = timestamp
        self.commandID = commandID
        self.type = type
        self.event = event
    }
}
