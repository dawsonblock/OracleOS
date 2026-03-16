import Foundation

// ─────────────────────────────────────────────────────────
// WorkflowIndex — in-memory workflow catalogue
//
// Stores WorkflowPlans keyed by ID. Provides query APIs for
// the planner and the strategy selector.
//
// The index intentionally has no persistence — plans are
// re-synthesized from the GraphStore on cold start.
// ─────────────────────────────────────────────────────────

/// In-memory catalogue of workflow plans.
///
/// `WorkflowIndex` is the single source of truth for plan lifecycle
/// within a runtime session. The planner reads from it via `matching(goal:)`
/// and `promotedPlans(for:)`.
public final class WorkflowIndex: @unchecked Sendable {

    // ── Configuration ───────────────────────────────────

    /// Plans older than this many days are considered stale.
    public static let staleDays: Double = 7.0

    /// Maximum plans stored (evict oldest candidates first).
    public static let maxPlans: Int = 200

    // ── Storage ─────────────────────────────────────────

    private var plans: [String: WorkflowPlan] = [:]

    public init() {}

    // ── Write ────────────────────────────────────────────

    /// Add or replace a plan.
    public func add(_ plan: WorkflowPlan) {
        if plans.count >= WorkflowIndex.maxPlans {
            evictOldestCandidate()
        }
        plans[plan.id] = plan
    }

    /// Update an existing plan in place (e.g. after recording success/failure).
    public func update(_ plan: WorkflowPlan) {
        plans[plan.id] = plan
    }

    /// Remove a plan by ID.
    public func remove(id: String) {
        plans.removeValue(forKey: id)
    }

    // ── Read ─────────────────────────────────────────────

    /// All plans sorted by descending success rate, then alphabetical pattern.
    public func allPlans() -> [WorkflowPlan] {
        plans.values.sorted { lhs, rhs in
            if lhs.successRate != rhs.successRate {
                return lhs.successRate > rhs.successRate
            }
            return lhs.goalPattern < rhs.goalPattern
        }
    }

    /// Promoted (non-stale) plans, optionally filtered by agent kind.
    public func promotedPlans(for agentKind: AgentKind? = nil) -> [WorkflowPlan] {
        allPlans().filter { plan in
            plan.promotionStatus == .promoted
            && !isStale(plan)
            && (agentKind == nil || agentKind == .mixed || plan.agentKind == agentKind || plan.agentKind == .mixed)
        }
    }

    /// Plans whose goal pattern overlaps the given goal description (all statuses).
    ///
    /// WorkflowMatcher applies the promoted/candidate filter on top of this.
    public func matching(goal: Goal) -> [WorkflowPlan] {
        let lower = goal.description.lowercased()
        let goalWords = Set(lower.split(separator: " ").map(String.init))
        return allPlans().filter { plan in
            let patWords = Set(plan.goalPattern.lowercased().split(separator: " ").map(String.init))
            return !goalWords.intersection(patWords).isEmpty
        }
    }

    /// Look up a single plan by ID.
    public func plan(id: String) -> WorkflowPlan? {
        plans[id]
    }

    /// Total number of plans stored.
    public var count: Int { plans.count }

    // ── Maintenance ──────────────────────────────────────

    /// Remove all stale plans (candidates and promoted) from the index.
    ///
    /// A plan is stale when neither its last success nor its creation date
    /// is within `staleDays`. Call periodically at goal boundaries.
    @discardableResult
    public func sweepStale() -> Int {
        let staleKeys = plans.filter { _, plan in isStale(plan) }.map(\.key)
        for key in staleKeys { plans.removeValue(forKey: key) }
        if !staleKeys.isEmpty {
            print("[workflowIndex] Removed \(staleKeys.count) stale plan(s)")
        }
        return staleKeys.count
    }

    // ── Private ──────────────────────────────────────────

    private func isStale(_ plan: WorkflowPlan) -> Bool {
        // Use most recent activity timestamp; fall back to creation date
        let reference = plan.lastSucceededAt ?? plan.createdAt
        return Date().timeIntervalSince(reference) > WorkflowIndex.staleDays * 86_400
    }

    private func evictOldestCandidate() {
        guard let oldest = plans.values
            .filter({ $0.promotionStatus == .candidate })
            .min(by: { $0.createdAt < $1.createdAt }) else { return }
        plans.removeValue(forKey: oldest.id)
    }
}
