import Foundation

// ─────────────────────────────────────────────────────────
// CriticLoop — post-action self-evaluation
//
// Evaluates every executed action by comparing pre/post state
// and classifying the outcome. The critic verdict drives:
//   • Graph edge promotion/demotion
//   • State memory updates
//   • Recovery signaling to the planner
//
// Architecture rule: the critic is a protected backbone module.
// It must not be bypassed, duplicated, or replaced.
// ─────────────────────────────────────────────────────────

/// Outcome classification for a single executed action.
public enum CriticVerdict: String {
    /// Action succeeded and postconditions confirmed
    case success
    /// Action partially succeeded — some postconditions met, others not
    case partialSuccess
    /// Action failed — postconditions not met or executor reported failure
    case failure
    /// Unable to determine outcome (insufficient observation data)
    case unknown
}

/// Detailed evaluation produced by the critic for one action.
public struct CriticEvaluation {
    public let actionID: String
    public let actionType: String
    public let verdict: CriticVerdict
    public let confidence: Double       // 0.0–1.0
    public let preStateHash: String
    public let postStateHash: String
    public let stateChanged: Bool
    public let detail: String
    public let timestamp: Date

    public init(
        actionID: String,
        actionType: String,
        verdict: CriticVerdict,
        confidence: Double,
        preStateHash: String,
        postStateHash: String,
        stateChanged: Bool,
        detail: String
    ) {
        self.actionID = actionID
        self.actionType = actionType
        self.verdict = verdict
        self.confidence = min(max(confidence, 0), 1)
        self.preStateHash = preStateHash
        self.postStateHash = postStateHash
        self.stateChanged = stateChanged
        self.detail = detail
        self.timestamp = Date()
    }
}

/// CriticLoop evaluates every action after execution.
///
/// Pipeline position:
///   executor result → CriticLoop.evaluate() → CriticEvaluation
///     → graph promotion/demotion
///     → recovery signal
///     → trace enrichment
public final class CriticLoop {

    /// History of evaluations for trend analysis
    private var evaluations: [CriticEvaluation] = []

    /// Read-only actions that are not expected to change state
    private static let readOnlyActions: Set<String> = [
        "log", "read_file", "list_directory", "noop",
        "get_context", "get_state", "find_element",
        "read_element", "inspect_element", "screenshot"
    ]

    public init() {}

    // ── Main evaluation entry ───────────────────────────

    /// Evaluate a single action's outcome.
    ///
    /// - Parameters:
    ///   - action: The intent that was executed
    ///   - result: The executor's raw result
    ///   - preStateHash: State hash captured before execution
    ///   - postStateHash: State hash captured after execution
    /// - Returns: A CriticEvaluation with verdict and confidence
    public func evaluate(
        action: ActionIntent,
        result: ExecutionResult,
        preStateHash: String,
        postStateHash: String
    ) -> CriticEvaluation {

        let stateChanged = preStateHash != postStateHash
        let isReadOnly = CriticLoop.readOnlyActions.contains(action.type)

        // ── Classification logic ────────────────────────

        let verdict: CriticVerdict
        let confidence: Double
        let detail: String

        if !result.executedThroughExecutor {
            // Trust boundary violation — always failure
            verdict = .failure
            confidence = 1.0
            detail = "bypassed executor trust boundary"

        } else if !result.success {
            // Executor reported failure
            if stateChanged {
                // Failed but state changed — partial side effects
                verdict = .partialSuccess
                confidence = 0.5
                detail = "execution failed but state was mutated — possible side effects"
            } else {
                verdict = .failure
                confidence = 0.9
                detail = "execution failed: \(result.detail)"
            }

        } else if isReadOnly {
            // Read-only action succeeded — no state change expected
            verdict = .success
            confidence = 0.95
            detail = "read-only action succeeded"

        } else if stateChanged {
            // Write action succeeded and state changed — confirmed success
            verdict = .success
            confidence = 0.9
            detail = "action succeeded with confirmed state change"

        } else {
            // Write action "succeeded" but no state change detected
            // This is suspicious — could be a no-op or observation gap
            verdict = .unknown
            confidence = 0.4
            detail = "action reported success but no state change detected"
        }

        // ── Adjust confidence from recent history ───────

        let adjustedConfidence = adjustForHistory(
            verdict: verdict,
            baseConfidence: confidence,
            actionType: action.type
        )

        let evaluation = CriticEvaluation(
            actionID: action.id,
            actionType: action.type,
            verdict: verdict,
            confidence: adjustedConfidence,
            preStateHash: preStateHash,
            postStateHash: postStateHash,
            stateChanged: stateChanged,
            detail: detail
        )

        evaluations.append(evaluation)
        print("[critic] \(verdict.rawValue) (\(String(format: "%.0f%%", adjustedConfidence * 100))): \(action.type) — \(detail)")

        return evaluation
    }

    // ── History queries ─────────────────────────────────

    /// Recent evaluations for trend analysis
    public func recentEvaluations(limit: Int = 20) -> [CriticEvaluation] {
        return Array(evaluations.suffix(limit))
    }

    /// Success rate for a specific action type
    public func successRate(forType type: String) -> Double {
        let relevant = evaluations.filter { $0.actionType == type }
        guard !relevant.isEmpty else { return 0.5 } // no data — neutral prior
        let successes = relevant.filter { $0.verdict == .success }.count
        return Double(successes) / Double(relevant.count)
    }

    /// Overall success rate across all actions
    public func overallSuccessRate() -> Double {
        guard !evaluations.isEmpty else { return 1.0 }
        let successes = evaluations.filter { $0.verdict == .success }.count
        return Double(successes) / Double(evaluations.count)
    }

    /// Whether recovery is recommended based on recent trend
    public func shouldRecommendRecovery() -> Bool {
        let recent = Array(evaluations.suffix(5))
        let failures = recent.filter { $0.verdict == .failure || $0.verdict == .unknown }.count
        return failures >= 3
    }

    // ── Confidence adjustment ───────────────────────────

    /// Adjust confidence based on historical performance of this action type.
    /// Repeated failures reduce confidence; repeated successes boost it.
    private func adjustForHistory(
        verdict: CriticVerdict,
        baseConfidence: Double,
        actionType: String
    ) -> Double {
        let history = evaluations.filter { $0.actionType == actionType }.suffix(10)
        guard history.count >= 2 else { return baseConfidence }

        let recentFailures = history.filter {
            $0.verdict == .failure || $0.verdict == .unknown
        }.count

        let failureRatio = Double(recentFailures) / Double(history.count)

        // High failure ratio reduces confidence
        let adjustment = failureRatio * 0.2
        return max(baseConfidence - adjustment, 0.1)
    }
}
