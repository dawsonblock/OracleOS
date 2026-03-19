import Foundation

// ─────────────────────────────────────────────────────────
// ExecutionResult — outcome of a verified action
//
// Every result is stamped with `executedThroughExecutor`.
// The runtime rejects any result without that flag.
// ─────────────────────────────────────────────────────────

public struct ExecutionResult {

    public let success: Bool
    public let detail: String
    public let executedThroughExecutor: Bool
    public let timestamp: Date
    public let actionID: String
    public let preStateHash: String
    public let postStateHash: String

    /// Policy decision code that authorized (or blocked) this action.
    /// Maps to PolicyDecision.DecisionCode.rawValue.
    public let policyDecisionCode: String

    public init(
        success: Bool,
        detail: String = "",
        executedThroughExecutor: Bool = true,
        actionID: String = "",
        preStateHash: String = "",
        postStateHash: String = "",
        policyDecisionCode: String = "allowed"
    ) {
        self.success = success
        self.detail = detail
        self.executedThroughExecutor = executedThroughExecutor
        self.timestamp = Date()
        self.actionID = actionID
        self.preStateHash = preStateHash
        self.postStateHash = postStateHash
        self.policyDecisionCode = policyDecisionCode
    }

    public static func blocked(actionID: String, reason: String) -> ExecutionResult {
        return ExecutionResult(
            success: false,
            detail: "BLOCKED: \(reason)",
            executedThroughExecutor: false,
            actionID: actionID,
            preStateHash: "",
            postStateHash: "",
            policyDecisionCode: "blocked"
        )
    }
}
