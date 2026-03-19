import Foundation

// ─────────────────────────────────────────────────────────
// StrategySelector — first-stage planner decision
//
// Chooses a SelectedStrategy based on goal text, agent kind,
// world snapshot, and recent failure count. Strategy selection
// is the mandatory first decision stage: no plan generation
// happens before this returns.
//
// Priority order:
//   1. Recovery mode (when recentFailureCount >= recoveryThreshold)
//   2. Permission / dialog conditions from goal text
//   3. AgentKind-specific strategy (code → repoRepair, etc.)
//   4. Goal-text keyword signals override agentKind default
// ─────────────────────────────────────────────────────────

/// Chooses a `SelectedStrategy` based on goal, world state, and agent kind.
///
/// Call `select(goal:snapshot:agentKind:recentFailureCount:)` at the top
/// of every planning cycle before calling the planner.
public final class StrategySelector {

    // ── Configuration ───────────────────────────────────

    /// Failure count at which the loop switches to recovery mode.
    public static let recoveryThreshold = 3

    // ── Keyword signal lists ─────────────────────────────

    private static let repairSignals = [
        "fix", "build", "compile", "error", "test", "patch",
        "lint", "refactor", "debug", "failing", "broken", "crash",
        "swift", "gradle", "cargo", "make", "npm",
    ]

    private static let browserSignals = [
        "browser", "safari", "chrome", "click", "navigate",
        "web", "url", "tab", "scroll", "page", "site", "http",
    ]

    private static let permissionSignals = [
        "permission", "allow", "grant", "access", "authorize",
        "approve", "consent",
    ]

    private static let diagnosticSignals = [
        "diagnose", "analyze", "analyse", "inspect", "audit",
        "check", "report", "diff", "coverage",
    ]

    // ── Init ────────────────────────────────────────────

    public init() {}

    // MARK: – Primary entry point

    /// Select the canonical `SelectedStrategy` for the current planning step.
    ///
    /// - Parameters:
    ///   - goal: The current agent goal.
    ///   - snapshot: Current world model snapshot (for future condition checks).
    ///   - agentKind: The classified kind of agent work (.ui / .code / .mixed).
    ///   - recentFailureCount: Consecutive failures since last success.
    /// - Returns: A `SelectedStrategy` constraining downstream plan generation.
    public func select(
        goal: Goal,
        snapshot: WorldModelSnapshot,
        agentKind: AgentKind,
        recentFailureCount: Int = 0
    ) -> SelectedStrategy {
        // ── 1. Recovery override ─────────────────────────
        if recentFailureCount >= StrategySelector.recoveryThreshold {
            let kind = StrategyKind.recoveryMode
            return SelectedStrategy(
                kind: kind,
                confidence: 0.90,
                rationale: buildRationale(kind: kind, goal: goal, agentKind: agentKind,
                                          note: "\(recentFailureCount) consecutive failures"),
                allowedOperatorFamilies: StrategyLibrary.allowedFamilies(for: kind),
                reevaluateAfterStepCount: 2
            )
        }

        // ── 2. Resolve kind from goal text + agentKind ───
        let kind = resolveKind(goal: goal, agentKind: agentKind)
        let confidence = baseConfidence(for: kind, agentKind: agentKind)
        let rationale = buildRationale(kind: kind, goal: goal, agentKind: agentKind)

        return SelectedStrategy(
            kind: kind,
            confidence: confidence,
            rationale: rationale,
            allowedOperatorFamilies: StrategyLibrary.allowedFamilies(for: kind),
            reevaluateAfterStepCount: reevaluateThreshold(for: kind)
        )
    }

    // MARK: – Private helpers

    private func resolveKind(goal: Goal, agentKind: AgentKind) -> StrategyKind {
        let lower = goal.description.lowercased()

        // Permission conditions win regardless of agent kind
        if Self.permissionSignals.contains(where: { lower.contains($0) }) {
            return .permissionResolution
        }

        // Diagnostic analysis for code/mixed when diagnostic keywords present
        if agentKind != .ui,
           Self.diagnosticSignals.contains(where: { lower.contains($0) }),
           !Self.repairSignals.contains(where: { lower.contains($0) }) {
            return .diagnosticAnalysis
        }

        switch agentKind {
        case .code:
            if Self.repairSignals.contains(where: { lower.contains($0) }) {
                return .repoRepair
            }
            return .graphNavigation

        case .ui:
            if Self.browserSignals.contains(where: { lower.contains($0) }) {
                return .browserInteraction
            }
            return .directExecution

        case .mixed:
            let hasRepair  = Self.repairSignals.contains(where: { lower.contains($0) })
            let hasBrowser = Self.browserSignals.contains(where: { lower.contains($0) })
            if hasRepair && hasBrowser { return .repoRepair }  // code side wins in mixed
            if hasRepair   { return .repoRepair }
            if hasBrowser  { return .browserInteraction }
            return .graphNavigation
        }
    }

    private func baseConfidence(for kind: StrategyKind, agentKind: AgentKind) -> Double {
        switch kind {
        case .recoveryMode:     return 0.90
        case .repoRepair        where agentKind == .code: return 0.85
        case .browserInteraction where agentKind == .ui:  return 0.85
        case .permissionResolution: return 0.80
        case .directExecution:  return 0.75
        case .graphNavigation:  return 0.70
        case .diagnosticAnalysis: return 0.70
        case .workflowExecution: return 0.92
        case .experimentMode:   return 0.60
        default:                return 0.65
        }
    }

    private func buildRationale(
        kind: StrategyKind,
        goal: Goal,
        agentKind: AgentKind,
        note: String = ""
    ) -> String {
        let goalPreview = String(goal.description.prefix(60))
        var parts = ["[\(kind.rawValue)]", "agentKind=\(agentKind.rawValue)", "goal='\(goalPreview)'"]
        if !note.isEmpty { parts.append("note=\(note)") }
        return parts.joined(separator: " ")
    }

    private func reevaluateThreshold(for kind: StrategyKind) -> Int {
        switch kind {
        case .recoveryMode:       return 2
        case .repoRepair,
             .diagnosticAnalysis: return 5
        case .experimentMode:     return 3
        default:                  return 5
        }
    }
}
