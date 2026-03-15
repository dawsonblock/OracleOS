import Foundation

// ─────────────────────────────────────────────────────────
// ExecutionCoordinator — skill resolution + policy gate
//
// Resolves an `ActionIntent` through `SkillRegistry` and
// evaluates it against `PolicyEngine` before the runtime
// hands it to `VerifiedActionExecutor`.
//
// Returns a `PreparedAction` — never executes anything itself.
//
// Architecture rule R4: this coordinator RESOLVES intent only.
// Execution is ALWAYS performed by VerifiedActionExecutor.
// ─────────────────────────────────────────────────────────

/// Prepares actions for execution: skill resolution → policy gate.
///
/// `ExecutionCoordinator` owns the skill-to-intent mapping and the
/// policy evaluation step. It returns a `PreparedAction` that the
/// runtime inspects before forwarding to `VerifiedActionExecutor`.
///
/// - Important: This coordinator prepares but never executes.
public final class ExecutionCoordinator {

    // ── Dependencies ────────────────────────────────────

    private let skillRegistry: SkillRegistry
    private let policy: PolicyEngine

    // ── Init ────────────────────────────────────────────

    public init(
        skillRegistry: SkillRegistry,
        policy: PolicyEngine
    ) {
        self.skillRegistry = skillRegistry
        self.policy = policy
    }

    // MARK: – Prepare from ActionIntent

    /// Resolve and validate an `ActionIntent` before execution.
    ///
    /// 1. Policy is evaluated first — fail fast before skill work.
    /// 2. The `SkillRegistry` is consulted for a matching OS skill
    ///    that can enrich the intent with resolved target metadata.
    /// 3. If no skill matches, the intent is forwarded as-is.
    ///
    /// - Parameters:
    ///   - intent: The raw intent produced by the planner.
    ///   - snapshot: The current world snapshot for skill resolution.
    /// - Returns: A `PreparedAction` describing whether execution is
    ///   allowed and what resolved intent to use.
    public func prepare(
        intent: ActionIntent,
        snapshot: WorldModelSnapshot
    ) -> PreparedAction {
        // Policy gate first — reject before doing skill work.
        guard policy.allow(action: intent) else {
            return PreparedAction(
                intent: intent,
                policyAllowed: false,
                blockReason: "policy denied: \(intent.type)"
            )
        }

        // Optional OS skill resolution (enriches intent metadata).
        if let skill = skillRegistry.get(intent.type),
           let resolution = try? skill.resolve(
               query: intent.type,
               worldSnapshot: snapshot,
               parameters: intent.parameters
           ) {
            return PreparedAction(
                intent: resolution.intent,
                policyAllowed: true,
                skillName: skill.name,
                confidence: resolution.confidence
            )
        }

        // No matching skill — use the intent as-is with full confidence.
        return PreparedAction(
            intent: intent,
            policyAllowed: true,
            confidence: 1.0
        )
    }

    // MARK: – Prepare from SkillResolution

    /// Validate a pre-resolved `SkillResolution` against policy.
    ///
    /// Use this when a skill has already been resolved upstream
    /// (e.g., via `SearchController.searchCandidates`).
    ///
    /// - Parameter resolution: The already-resolved skill resolution.
    /// - Returns: A `PreparedAction` ready for the executor.
    public func prepare(resolution: SkillResolution) -> PreparedAction {
        guard policy.allow(action: resolution.intent) else {
            return PreparedAction(
                intent: resolution.intent,
                policyAllowed: false,
                blockReason: "policy denied (resolution): \(resolution.intent.type)"
            )
        }

        return PreparedAction(
            intent: resolution.intent,
            policyAllowed: true,
            confidence: resolution.confidence
        )
    }
}
