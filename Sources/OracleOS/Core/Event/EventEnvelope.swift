import Foundation

public struct EventEnvelope: Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: TimeInterval
    public let event: Data
    public let type: String

    public init(
        id: UUID = UUID(),
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        event: Data,
        type: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.type = type
    }
}
