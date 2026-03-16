import Foundation

// ─────────────────────────────────────────────────────────
// RecoveryCoordinator — bounded failure recovery
//
// When the CriticLoop classifies an action as FAILURE or
// PARTIAL_SUCCESS, the RecoveryCoordinator decides what to
// do next. Recovery is bounded:
//   • Max retries per action (default 2)
//   • Max total recovery attempts per goal (default 5)
//   • Escalation to abort when limits are hit
//
// Architecture rule: RecoveryCoordinator owns recovery
// workflows and recovery execution. It does NOT own
// planning decisions or state building.
// ─────────────────────────────────────────────────────────

/// What the recovery coordinator decides to do about a failed action.
public enum RecoveryDecision {
    /// Retry the same action (possibly with adjusted parameters)
    case retry(ActionIntent)
    /// Skip this action and continue with the rest of the plan
    case skip(reason: String)
    /// Abort the entire plan — too many failures
    case abort(reason: String)
}

/// Tracks retry state for a single goal's execution.
public struct RecoveryState {
    public let goalID: String
    public var retryCountPerAction: [String: Int] = [:]  // actionID → retry count
    public var totalRecoveryAttempts: Int = 0

    public init(goalID: String) {
        self.goalID = goalID
    }
}

/// RecoveryCoordinator manages bounded failure recovery.
public final class RecoveryCoordinator {

    /// Maximum retries for any single action
    public static let maxRetriesPerAction = 2

    /// Maximum total recovery attempts across all actions in one goal
    public static let maxRecoveryPerGoal = 5

    /// Active recovery states keyed by goal ID
    private var states: [String: RecoveryState] = [:]

    public init() {}

    // ── Main decision entry ─────────────────────────────

    /// Decide how to handle a failed action.
    ///
    /// - Parameters:
    ///   - action: The action that failed
    ///   - evaluation: The critic's evaluation of the failure
    ///   - goalID: The goal this action belongs to
    /// - Returns: A RecoveryDecision (retry, skip, or abort)
    public func recover(
        action: ActionIntent,
        evaluation: CriticEvaluation,
        goalID: String
    ) -> RecoveryDecision {

        // Initialize recovery state for this goal if needed
        if states[goalID] == nil {
            states[goalID] = RecoveryState(goalID: goalID)
        }
        var state = states[goalID]!

        // Check global recovery budget
        guard state.totalRecoveryAttempts < RecoveryCoordinator.maxRecoveryPerGoal else {
            let reason = "recovery budget exhausted (\(state.totalRecoveryAttempts)/\(RecoveryCoordinator.maxRecoveryPerGoal) attempts)"
            print("[recovery] ABORT: \(reason)")
            return .abort(reason: reason)
        }

        // Check per-action retry budget
        let currentRetries = state.retryCountPerAction[action.id, default: 0]
        guard currentRetries < RecoveryCoordinator.maxRetriesPerAction else {
            let reason = "max retries reached for \(action.type) (\(currentRetries)/\(RecoveryCoordinator.maxRetriesPerAction))"
            print("[recovery] SKIP: \(reason)")
            return .skip(reason: reason)
        }

        // Decide based on verdict
        switch evaluation.verdict {
        case .failure:
            // Retry with the same action
            state.retryCountPerAction[action.id, default: 0] += 1
            state.totalRecoveryAttempts += 1
            states[goalID] = state

            let retryAction = ActionIntent(
                type: action.type,
                domain: action.domain,
                parameters: action.parameters.merging(
                    ["_recovery_attempt": "\(currentRetries + 1)"],
                    uniquingKeysWith: { _, new in new }
                ),
                id: action.id  // preserve ID for retry tracking
            )
            print("[recovery] RETRY #\(currentRetries + 1): \(action.type)")
            return .retry(retryAction)

        case .partialSuccess:
            // Partial success — skip and let the plan continue
            // (side effects already occurred, retrying could duplicate them)
            state.totalRecoveryAttempts += 1
            states[goalID] = state
            print("[recovery] SKIP (partial): \(action.type) — side effects may have occurred")
            return .skip(reason: "partial success — skipping to avoid duplicate side effects")

        case .unknown:
            // Unknown — retry once, then skip
            if currentRetries == 0 {
                state.retryCountPerAction[action.id, default: 0] += 1
                state.totalRecoveryAttempts += 1
                states[goalID] = state
                print("[recovery] RETRY (unknown verdict): \(action.type)")
                return .retry(action)
            } else {
                return .skip(reason: "unknown verdict persists after retry")
            }

        case .success:
            // Should not reach here — success doesn't need recovery
            return .skip(reason: "no recovery needed for success")
        }
    }

    // ── State queries ───────────────────────────────────

    /// Get the current recovery state for a goal
    public func state(forGoal goalID: String) -> RecoveryState? {
        return states[goalID]
    }

    /// Total recovery attempts across all goals
    public func totalRecoveryAttempts() -> Int {
        return states.values.reduce(0) { $0 + $1.totalRecoveryAttempts }
    }

    /// Clear recovery state (e.g. when a goal completes)
    public func clearState(forGoal goalID: String) {
        states.removeValue(forKey: goalID)
    }

    /// Reset all recovery state
    public func reset() {
        states.removeAll()
    }
}
