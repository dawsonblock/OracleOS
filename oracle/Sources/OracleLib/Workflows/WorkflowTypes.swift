import Foundation

// ─────────────────────────────────────────────────────────
// WorkflowTypes — core data model for the workflow layer
//
// Workflows are reusable action sequences promoted from
// successful execution traces. Promotion enforces R10:
// repeated critic-confirmed success across distinct episodes.
//
// Lifecycle:
//   trace → synthesize → candidate → (3 successes) → promoted
//   → stale (after decay) / rejected (on failure)
// ─────────────────────────────────────────────────────────

// MARK: – WorkflowPromotionStatus

/// The lifecycle state of a workflow plan.
public enum WorkflowPromotionStatus: String, Equatable, CaseIterable, Sendable {
    /// Not yet validated — awaiting enough confirmed successes.
    case candidate
    /// Validated and promoted — used by the planner.
    case promoted
    /// Rejected due to repeated failure or policy violation.
    case rejected
    /// Previously promoted but too old to trust without re-validation.
    case stale
}

// MARK: – WorkflowStep

/// A single action step within a workflow plan.
public struct WorkflowStep: Equatable, Sendable {

    public let id: String
    /// The action type this step executes.
    public let actionType: String
    /// The skill that resolves the action type.
    public let skillName: String
    /// Whether this step requires UI or code context.
    public let agentKind: AgentKind
    /// Optional free-text notes (debug / provenance).
    public let notes: [String]

    public init(
        id: String = UUID().uuidString,
        actionType: String,
        skillName: String,
        agentKind: AgentKind = .mixed,
        notes: [String] = []
    ) {
        self.id = id
        self.actionType = actionType
        self.skillName = skillName
        self.agentKind = agentKind
        self.notes = notes
    }
}

// MARK: – WorkflowPlan

/// A reusable action sequence derived from one or more execution traces.
///
/// Plans start as `.candidate` and are promoted to `.promoted` once they
/// accumulate `WorkflowPromoter.promotionThreshold` distinct confirmed
/// successes (R10 — conservative learning).
public struct WorkflowPlan: Equatable, Sendable {

    public let id: String
    public let agentKind: AgentKind
    public let goalPattern: String
    public let steps: [WorkflowStep]

    // ── Statistics ───────────────────────────────────────

    public private(set) var successCount: Int
    public private(set) var attemptCount: Int
    public private(set) var promotionStatus: WorkflowPromotionStatus
    public let createdAt: Date
    public private(set) var lastSucceededAt: Date?

    public init(
        id: String = UUID().uuidString,
        agentKind: AgentKind,
        goalPattern: String,
        steps: [WorkflowStep],
        successCount: Int = 0,
        attemptCount: Int = 0,
        promotionStatus: WorkflowPromotionStatus = .candidate,
        createdAt: Date = Date(),
        lastSucceededAt: Date? = nil
    ) {
        self.id = id
        self.agentKind = agentKind
        self.goalPattern = goalPattern
        self.steps = steps
        self.successCount = successCount
        self.attemptCount = attemptCount
        self.promotionStatus = promotionStatus
        self.createdAt = createdAt
        self.lastSucceededAt = lastSucceededAt
    }

    // ── Derived metrics ─────────────────────────────────

    /// Historical success rate (0.0 when no attempts have been recorded).
    public var successRate: Double {
        guard attemptCount > 0 else { return 0.0 }
        return Double(successCount) / Double(attemptCount)
    }

    // ── Mutations ────────────────────────────────────────

    /// Record a successful replay of this workflow.
    public mutating func recordSuccess() {
        successCount += 1
        attemptCount += 1
        lastSucceededAt = Date()
    }

    /// Record a failed replay of this workflow.
    public mutating func recordFailure() {
        attemptCount += 1
    }

    /// Update the promotion status.
    public mutating func setPromotionStatus(_ status: WorkflowPromotionStatus) {
        promotionStatus = status
    }
}
