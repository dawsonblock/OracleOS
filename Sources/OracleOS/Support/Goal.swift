import Foundation

/// Defines the objective of a user-initiated or agent-generated task.
public struct GoalRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let objective: String
    public let source: GoalSource
    public let priority: Int
    public let createdAt: Date
    public let deadline: Date?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        title: String,
        objective: String,
        source: GoalSource = .user,
        priority: Int = 1,
        createdAt: Date = Date(),
        deadline: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.objective = objective
        self.source = source
        self.priority = priority
        self.createdAt = createdAt
        self.deadline = deadline
        self.metadata = metadata
    }
}

public enum GoalSource: String, Codable, Sendable {
    case user
    case capsule
    case autonomous
}
