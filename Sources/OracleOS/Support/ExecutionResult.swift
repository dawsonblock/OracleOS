import Foundation

/// Represents the executable result of a command within the runtime.
public struct ExecutionResult: Codable, Sendable {
    public let commandId: UUID
    public let timestamp: Date
    public let durationMs: Int
    public let exitReason: ExecutionExitReason
    public let failureType: ExecutionFailureType?

    /// Evidence collected from execution (logs, tool output, etc.)
    public let evidence: [String: String]
    /// Boolean flags indicating whether postconditions were satisfied.
    public let postconditionStatus: [String: Bool]

    public var success: Bool {
        exitReason == .complete
    }

    public init(
        commandId: UUID,
        timestamp: Date = Date(),
        durationMs: Int,
        exitReason: ExecutionExitReason,
        failureType: ExecutionFailureType? = nil,
        evidence: [String: String] = [:],
        postconditionStatus: [String: Bool] = [:]
    ) {
        self.commandId = commandId
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.exitReason = exitReason
        self.failureType = failureType
        self.evidence = evidence
        self.postconditionStatus = postconditionStatus
    }
}

public enum ExecutionExitReason: String, Codable, Sendable {
    case complete
    case failed
    case timeout
    case aborted
}

public enum ExecutionFailureType: String, Codable, Sendable {
    case preconditionViolation
    case toolError
    case permissionDenied
    case rateLimited
    case connectivityIssue
    case policyViolation
    case unknown
}
