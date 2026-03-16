import Foundation

// ─────────────────────────────────────────────────────────
// TaskEdge — transition between two TaskNodes
//
// Tracks both candidate (planned but not yet executed) and
// executed transitions. Evidence accumulates over repeated
// attempts so the planner can estimate successProbability
// for path scoring.
//
// ARCHITECTURE_RULES.md: protected backbone (TaskGraph).
// ─────────────────────────────────────────────────────────

/// Status of a TaskEdge.
public enum TaskEdgeStatus: String {
    case candidate
    case executedSuccess  = "executed_success"
    case executedFailure  = "executed_failure"
    case abandoned
}

/// Represents a possible or executed transition between two TaskNodes.
public final class TaskEdge {

    public let id: String
    public let fromNodeID: String
    public let toNodeID: String
    public let action: String
    public let domain: ActionDomain
    public private(set) var status: TaskEdgeStatus
    public private(set) var successCount: Int
    public private(set) var failureCount: Int
    public private(set) var totalCost: Double
    public private(set) var totalLatencyMs: Double
    public private(set) var lastAttemptTimestamp: TimeInterval?
    public let createdTimestamp: TimeInterval

    public init(
        id: String = UUID().uuidString,
        fromNodeID: String,
        toNodeID: String,
        action: String,
        domain: ActionDomain = .system,
        status: TaskEdgeStatus = .candidate,
        successCount: Int = 0,
        failureCount: Int = 0,
        totalCost: Double = 0,
        totalLatencyMs: Double = 0
    ) {
        self.id = id
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.action = action
        self.domain = domain
        self.status = status
        self.successCount = successCount
        self.failureCount = failureCount
        self.totalCost = totalCost
        self.totalLatencyMs = totalLatencyMs
        self.lastAttemptTimestamp = nil
        self.createdTimestamp = Date().timeIntervalSince1970
    }

    // ── Evidence ────────────────────────────────────────

    public var attempts: Int {
        successCount + failureCount
    }

    public var successProbability: Double {
        guard attempts > 0 else { return 0 }
        return Double(successCount) / Double(attempts)
    }

    public var averageLatencyMs: Double {
        guard attempts > 0 else { return 0 }
        return totalLatencyMs / Double(attempts)
    }

    public var averageCost: Double {
        guard attempts > 0 else { return 0 }
        return totalCost / Double(attempts)
    }

    // ── Recording ───────────────────────────────────────

    public func recordSuccess(latencyMs: Double = 0, cost: Double = 0) {
        successCount += 1
        totalLatencyMs += latencyMs
        totalCost += cost
        lastAttemptTimestamp = Date().timeIntervalSince1970
        status = .executedSuccess
    }

    public func recordFailure(latencyMs: Double = 0, cost: Double = 0) {
        failureCount += 1
        totalLatencyMs += latencyMs
        totalCost += cost
        lastAttemptTimestamp = Date().timeIntervalSince1970
        status = .executedFailure
    }

    public func markAbandoned() {
        status = .abandoned
    }
}
