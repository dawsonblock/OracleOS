import Foundation

/// A fully specified, idempotent-aware instruction for the VerifiedActionExecutor.
public struct ActionCommand: Codable, Sendable, Identifiable {
    public let id: UUID
    public let goalId: UUID?
    public let actionType: ActionType
    public let intent: ActionIntent
    
    /// Execution metadata
    public let timeout: TimeInterval
    public let retryPolicy: ActionRetryPolicy
    public let traceId: String
    
    /// Security & Context
    public let operatorIdentity: String?
    public let metadata: [String: String]

    public var isIdempotent: Bool {
        switch actionType {
        case .perception: return true
        default: return intent.isIdempotent
        }
    }

    public init(
        id: UUID = UUID(),
        goalId: UUID? = nil,
        actionType: ActionType,
        intent: ActionIntent,
        timeout: TimeInterval = 30.0,
        retryPolicy: ActionRetryPolicy = .none,
        traceId: String = UUID().uuidString,
        operatorIdentity: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.goalId = goalId
        self.actionType = actionType
        self.intent = intent
        self.timeout = timeout
        self.retryPolicy = retryPolicy
        self.traceId = traceId
        self.operatorIdentity = operatorIdentity
        self.metadata = metadata
    }
}

public enum ActionRetryPolicy: String, Codable, Sendable {
    case none
    case simple(maxRetries: Int)
    case exponentialBackoff(maxRetries: Int, baseDelay: TimeInterval)
}

extension ActionIntent {
    /// Heuristic to determine if an action is safe to retry.
    public var isIdempotent: Bool {
        // Broad strokes for Phase 4/5 integration.
        switch action {
        case "click", "type", "drag", "press": return false
        case "read", "list", "search", "get": return true
        default: return false
        }
    }
}
