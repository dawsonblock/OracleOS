import Foundation

// ─────────────────────────────────────────────────────────
// WorkflowSynthesizer — build WorkflowPlans from execution traces
//
// Converts critic-confirmed execution traces into candidate
// WorkflowPlans. The synthesizer does NOT promote plans —
// that is enforced by WorkflowPromoter (R10).
//
// Minimum trace length: 2 steps.
// Only traces with success == true are used.
// ─────────────────────────────────────────────────────────

/// Creates candidate `WorkflowPlan` values from execution traces.
///
/// Synthesis is conservative:
///   • Requires at least `minTraceLength` successful steps.
///   • Only fully-successful traces (all steps `success == true`) are used.
///   • Output plans start in `.candidate` state — WorkflowPromoter decides
///     when to promote (R10: repeated critic-confirmed success required).
public enum WorkflowSynthesizer {

    // ── Configuration ───────────────────────────────────

    /// Minimum number of successful steps to synthesize a workflow.
    public static let minTraceLength = 2

    // MARK: – Primary API

    /// Synthesize a `WorkflowPlan` from a sequence of execution traces.
    ///
    /// - Parameters:
    ///   - traces: Ordered execution traces for a single goal episode.
    ///     Only traces where `success == true` contribute steps.
    ///   - goalPattern: Short description of the task class (stored in the plan).
    ///   - agentKind: The agent kind for the resulting plan.
    /// - Returns: A `.candidate` `WorkflowPlan`, or `nil` if the trace is
    ///   too short or has no successful steps.
    public static func synthesize(
        from traces: [ExecutionTrace],
        goalPattern: String,
        agentKind: AgentKind = .mixed
    ) -> WorkflowPlan? {
        let successful = traces.filter { $0.success }
        guard successful.count >= minTraceLength else { return nil }

        let steps = successful.map { trace in
            WorkflowStep(
                actionType: trace.actionType,
                skillName: trace.actionType,  // 1:1 mapping until skill inference is wired
                agentKind: agentKind
            )
        }

        return WorkflowPlan(
            agentKind: agentKind,
            goalPattern: goalPattern.isEmpty ? "unknown" : goalPattern,
            steps: steps
        )
    }

    /// Synthesize a workflow from a group of traces sharing the same goal.
    ///
    /// Deduplicates consecutive identical action types to produce a
    /// compact canonical action sequence.
    public static func synthesizeDeduped(
        from traces: [ExecutionTrace],
        goalPattern: String,
        agentKind: AgentKind = .mixed
    ) -> WorkflowPlan? {
        let successful = traces.filter { $0.success }
        guard successful.count >= minTraceLength else { return nil }

        // Remove consecutive duplicates
        var deduped: [ExecutionTrace] = []
        for trace in successful {
            if deduped.last?.actionType != trace.actionType {
                deduped.append(trace)
            }
        }

        guard deduped.count >= minTraceLength else { return nil }

        let steps = deduped.map { trace in
            WorkflowStep(
                actionType: trace.actionType,
                skillName: trace.actionType,
                agentKind: agentKind
            )
        }

        return WorkflowPlan(
            agentKind: agentKind,
            goalPattern: goalPattern.isEmpty ? "unknown" : goalPattern,
            steps: steps
        )
    }
}
