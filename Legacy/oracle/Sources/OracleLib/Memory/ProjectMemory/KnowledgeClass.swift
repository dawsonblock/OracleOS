import Foundation

// MARK: - KnowledgeClass

/// Classification of a project memory record by its knowledge durability.
public enum KnowledgeClass: String, Codable, Sendable, CaseIterable {
    case reusable
    case parameter
    case episode
}
