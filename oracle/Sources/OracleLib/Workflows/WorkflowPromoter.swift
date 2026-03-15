import Foundation

// ─────────────────────────────────────────────────────────
// WorkflowPromoter — R10 conservative workflow promotion
//
// R10: Workflow promotion must be gated on repeated,
//      critic-confirmed success — never on a single episode.
//
// A plan is promoted only after `promotionThreshold` recorded
// successes. It is rejected after `rejectionThreshold` failures
// WHILE the plan is in a non-rejected state.
//
// WorkflowPromoter does not touch the WorkflowIndex directly;
// callers retrieve the plan, call record/evaluate, then update.
// ─────────────────────────────────────────────────────────

/// Enforces R10: conservative, threshold-gated workflow promotion.
///
/// Usage pattern:
/// ```swift
/// var plan = index.plan(id: id) ?? return
/// WorkflowPromoter.recordOutcome(success: true, plan: &plan)
/// WorkflowPromoter.evaluate(plan: &plan)
/// index.update(plan)
/// ```
public enum WorkflowPromoter {

    // ── Configuration ───────────────────────────────────

    /// Number of successful episodes required to promote a candidate.
    public static let promotionThreshold = 3

    /// Number of consecutive failures required to reject a promoted plan.
    public static let rejectionThreshold = 3

    // MARK: – Outcome Recording

    /// Record a critic-confirmed outcome for a plan.
    ///
    /// Updates `successCount`, `attemptCount`, and `lastSucceededAt`.
    /// Does NOT change `promotionStatus` — call `evaluate(plan:)` after.
    public static func recordOutcome(success: Bool, plan: inout WorkflowPlan) {
        if success {
            plan.recordSuccess()
        } else {
            plan.recordFailure()
        }
    }

    // MARK: – Promotion Evaluation

    /// Evaluate the promotion status of a plan based on its outcome history.
    ///
    /// - Candidate → Promoted: when `successCount >= promotionThreshold`.
    /// - Promoted  → Rejected: when failure streak × attemptCount indicates
    ///   `(attemptCount - successCount) >= rejectionThreshold` AND success rate < 0.4.
    /// - Rejected plans are not re-evaluated.
    /// - Stale plans (set externally by WorkflowIndex.sweepStale) are not touched.
    public static func evaluate(plan: inout WorkflowPlan) {
        switch plan.promotionStatus {
        case .candidate:
            if plan.successCount >= promotionThreshold {
                plan.setPromotionStatus(.promoted)
            }

        case .promoted:
            let failures = plan.attemptCount - plan.successCount
            if failures >= rejectionThreshold && plan.successRate < 0.6 {
                plan.setPromotionStatus(.rejected)
            }

        case .rejected, .stale:
            break  // terminal states — no transitions
        }
    }

    // MARK: – Convenience

    /// Returns `true` when the plan meets the promotion threshold.
    public static func shouldPromote(_ plan: WorkflowPlan) -> Bool {
        plan.promotionStatus == .candidate && plan.successCount >= promotionThreshold
    }

    /// Returns `true` when the plan should be demoted from `.promoted`.
    public static func shouldReject(_ plan: WorkflowPlan) -> Bool {
        guard plan.promotionStatus == .promoted else { return false }
        let failures = plan.attemptCount - plan.successCount
        return failures >= rejectionThreshold && plan.successRate < 0.6
    }
}
