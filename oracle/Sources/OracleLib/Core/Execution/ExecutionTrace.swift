import Foundation

// ─────────────────────────────────────────────────────────
// ExecutionTrace — immutable record of one executed action
// ─────────────────────────────────────────────────────────

public struct ExecutionTrace {

    public let id: String
    public let timestamp: Date
    public let actionID: String
    public let actionType: String
    public let preStateHash: String
    public let postStateHash: String
    public let verified: Bool
    public let success: Bool

    public init(
        actionID: String,
        actionType: String,
        preStateHash: String,
        postStateHash: String,
        verified: Bool,
        success: Bool,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.timestamp = Date()
        self.actionID = actionID
        self.actionType = actionType
        self.preStateHash = preStateHash
        self.postStateHash = postStateHash
        self.verified = verified
        self.success = success
    }
}
