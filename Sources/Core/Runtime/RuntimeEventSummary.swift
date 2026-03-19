import Foundation

public struct RuntimeEventSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let commandID: UUID
    public let timestamp: TimeInterval
    public let type: String
    public let success: Bool
    public let timedOut: Bool
    public let summary: String
    public let details: [String: String]

    public init(
        id: UUID,
        commandID: UUID,
        timestamp: TimeInterval,
        type: String,
        success: Bool,
        timedOut: Bool,
        summary: String,
        details: [String: String]
    ) {
        self.id = id
        self.commandID = commandID
        self.timestamp = timestamp
        self.type = type
        self.success = success
        self.timedOut = timedOut
        self.summary = summary
        self.details = details
    }
}
