import Foundation

/// A high-level runtime request, capturing user intent before planning.
public struct Intent: Codable, Sendable {
    public let id: UUID
    public let goalId: UUID?
    public let rawQuery: String
    public let timestamp: Date
    public let context: [String: String]

    public init(
        id: UUID = UUID(),
        goalId: UUID? = nil,
        rawQuery: String,
        timestamp: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.id = id
        self.goalId = goalId
        self.rawQuery = rawQuery
        self.timestamp = timestamp
        self.context = context
    }
}
