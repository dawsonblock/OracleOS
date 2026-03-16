import Foundation

// ─────────────────────────────────────────────────────────
// VerifiedActionExecutor — the single execution truth boundary
//
// EVERY environment-changing action flows through here.
// No external system bypasses this. MCP, CLI, recipes,
// recovery — all converge on execute(action:).
//
// Pipeline:
//   intent
//     → validator (registered action?)
//     → policy → PolicyDecision (not Bool)
//     → pre-observation (WorldModelSnapshot)
//     → execute
//     → post-observation (WorldModelSnapshot)
//     → postcondition verification
//     → stamp executedThroughExecutor
//     → trace
//     → result
//
// Blueprint ref: Gate 1, §1.2 — "single execution truth boundary"
// Invariant: result.executedThroughExecutor == true on every path
// ─────────────────────────────────────────────────────────

public final class VerifiedActionExecutor {

    private var policy: PolicyEngine?
    private var traceRecorder: TraceRecorder?

    /// Optional snapshot provider (Gate 2 fills real implementation).
    /// When nil, falls back to deterministic hash stubs.
    public var worldStateProvider: WorldStateProvider?

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

        // 2. Policy evaluation → typed PolicyDecision
        let decision: PolicyDecision
        if let policy = policy {
            decision = policy.evaluate(action: action)
        } else {
            decision = .allow(reason: "no policy engine attached")
        }

        guard decision.allowed else {
            print("[executor] BLOCKED: \(action.type) — \(decision.reason) [code: \(decision.decisionCode)]")
            return ExecutionResult.blocked(
                actionID: action.id,
                reason: "\(decision.decisionCode): \(decision.reason)"
            )
        }

        // 3. Pre-observation snapshot
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
            postStateHash: postState,
            policyDecisionCode: decision.decisionCode.rawValue
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

    // ── Legacy compatibility ────────────────────────────
    //
    // Backward-compatible allow() wrapper removed — callers
    // now see the full PolicyDecision through the result.

    // ── Observation ─────────────────────────────────────

    private func capturePreState(action: ActionIntent) -> String {
        if let provider = worldStateProvider {
            return provider.snapshot(label: "pre-\(action.id)").hash
        }
        return "pre-\(action.id.prefix(8))"
    }

    private func capturePostState(action: ActionIntent) -> String {
        if let provider = worldStateProvider {
            return provider.snapshot(label: "post-\(action.id)").hash
        }
        return "post-\(action.id.prefix(8))"
    }
}

// ─────────────────────────────────────────────────────────
// WorldStateProvider — protocol for snapshot capture
//
// Gate 2 delivers the real implementation backed by
// WorldStateModel. For now, stub implementations can
// conform to this protocol.
// ─────────────────────────────────────────────────────────

public protocol WorldStateProvider {
    func snapshot(label: String) -> WorldStateSnapshot
}

public struct WorldStateSnapshot {
    public let label: String
    public let hash: String
    public let timestamp: Date

    public init(label: String, hash: String, timestamp: Date = Date()) {
        self.label = label
        self.hash = hash
        self.timestamp = timestamp
    }
}
