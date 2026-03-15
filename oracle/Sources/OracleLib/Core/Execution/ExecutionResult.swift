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

    public init(
        success: Bool,
        detail: String = "",
        executedThroughExecutor: Bool = true,
        actionID: String = ""
    ) {
        self.success = success
        self.detail = detail
        self.executedThroughExecutor = executedThroughExecutor
        self.timestamp = Date()
        self.actionID = actionID
    }

    public static func blocked(actionID: String, reason: String) -> ExecutionResult {
        return ExecutionResult(
            success: false,
            detail: "BLOCKED: \(reason)",
            executedThroughExecutor: false,
            actionID: actionID
        )
    }
}
