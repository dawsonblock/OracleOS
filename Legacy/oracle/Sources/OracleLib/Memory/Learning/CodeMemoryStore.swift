import Foundation

// MARK: - CodeMemoryStore

/// In-memory store for code-specific memory: error patterns, fix patterns, and
/// command success/failure counts.
public struct CodeMemoryStore: Sendable {
    public var errorPatterns: [String: ErrorPattern]
    public var fixPatterns: [String: FixPattern]
    public var commandSuccesses: [String: Int]
    public var commandFailures: [String: Int]

    public init(
        errorPatterns: [String: ErrorPattern] = [:],
        fixPatterns: [String: FixPattern] = [:],
        commandSuccesses: [String: Int] = [:],
        commandFailures: [String: Int] = [:]
    ) {
        self.errorPatterns = errorPatterns
        self.fixPatterns = fixPatterns
        self.commandSuccesses = commandSuccesses
        self.commandFailures = commandFailures
    }
}
