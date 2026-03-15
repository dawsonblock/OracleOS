import Foundation

// ─────────────────────────────────────────────────────────
// VerifiedActionExecutor — the execution truth boundary
//
// EVERY environment-changing action flows through here.
// No external system bypasses this.
//
// Pipeline:
//   intent
//     → validator (registered action?)
//     → policy (allowed?)
//     → pre-observation
//     → execute
//     → post-observation
//     → postcondition verification
//     → stamp executedThroughExecutor
//     → trace
//     → result
// ─────────────────────────────────────────────────────────

public final class VerifiedActionExecutor {

    private var policy: PolicyEngine?
    private var traceRecorder: TraceRecorder?

    public init() {}

    public func attachPolicy(_ policy: PolicyEngine) {
        self.policy = policy
    }

    public func attachTraceRecorder(_ recorder: TraceRecorder) {
        self.traceRecorder = recorder
    }

    // ── Main execution path ─────────────────────────

    public func execute(action: ActionIntent) -> ExecutionResult {

        // 1. Validate action is registered
        guard ActionRegistry.shared.isRegistered(action.type) else {
            let msg = "unregistered action: \(action.type)"
            print("[executor] REJECTED: \(msg)")
            return ExecutionResult(
                success: false,
                detail: msg,
                executedThroughExecutor: true,
                actionID: action.id
            )
        }

        // 2. Policy check (defense in depth — runtime also checks)
        if let policy = policy, !policy.allow(action: action) {
            return ExecutionResult.blocked(actionID: action.id, reason: "policy denied")
        }

        // 3. Pre-observation snapshot (placeholder for Phase 6)
        let preState = capturePreState(action: action)

        // 4. Execute through registered handler
        let handler = ActionRegistry.shared.handler(for: action.type)
        let rawResult = handler(action)

        // 5. Post-observation snapshot
        let postState = capturePostState(action: action)

        // 6. Postcondition verification
        let verified = PostconditionVerifier.verify(
            action: action,
            preState: preState,
            postState: postState,
            rawResult: rawResult
        )

        // 7. Stamp and return (include state hashes for critic evaluation)
        let result = ExecutionResult(
            success: verified && rawResult.success,
            detail: rawResult.detail,
            executedThroughExecutor: true,
            actionID: action.id,
            preStateHash: preState,
            postStateHash: postState
        )

        // 8. Execution trace — record through TraceRecorder if attached
        let trace = ExecutionTrace(
            actionID: action.id,
            actionType: action.type,
            preStateHash: preState,
            postStateHash: postState,
            verified: verified,
            success: result.success
        )
        traceRecorder?.record(
            TraceEvent(
                action: action,
                outcome: result.success ? .success : .failure,
                detail: result.detail
            )
        )
        _ = trace

        return result
    }

    // ── Observation (stub — Phase 6 fills this) ─────────

    private func capturePreState(action: ActionIntent) -> String {
        return "pre-\(action.id.prefix(8))"
    }

    private func capturePostState(action: ActionIntent) -> String {
        return "post-\(action.id.prefix(8))"
    }
}
