import Foundation

// ─────────────────────────────────────────────────────────
// PolicyEngine — gating authority for all actions
//
// Evaluates authorization based on:
//   • action type
//   • target path / workspace boundary
//   • domain
//   • mutation level
//   • caller surface
//   • risk level
//
// Returns a typed PolicyDecision — never a bare Bool.
// Ambiguous policy states fail closed.
//
// Blueprint ref: Gate 1, §1.3
// ─────────────────────────────────────────────────────────

public final class PolicyEngine {

    private var rules: [PolicyRule] = []
    private var allowlist = CapabilityAllowlist()

    /// Workspace root for boundary checks (nil = no workspace constraint).
    public var workspaceBoundary: String?

    public init() {
        loadDefaultRules()
    }

    // ── Core gate (typed) ───────────────────────────────

    /// Evaluate full policy for an action. Returns a typed decision.
    public func evaluate(action: ActionIntent) -> PolicyDecision {

        // 1. Workspace boundary check for write actions
        if action.requiresMutation, let boundary = workspaceBoundary {
            if let target = action.targetScope ?? action.parameters["path"] {
                let resolvedTarget = (target as NSString).standardizingPath
                let resolvedBoundary = (boundary as NSString).standardizingPath
                if !resolvedTarget.hasPrefix(resolvedBoundary) {
                    return .deny(
                        reason: "write target '\(target)' is outside workspace '\(boundary)'",
                        code: .outsideWorkspace
                    )
                }
            }
        }

        // 2. Explicit rule checks
        for rule in rules {
            if rule.matches(action: action) {
                switch rule.decision {
                case .block:
                    return .deny(reason: "rule '\(rule.name)' blocked \(action.type)")
                case .requireApproval:
                    if action.approvalToken != nil {
                        // Approval provided — allow through
                        break
                    }
                    return .pendingApproval(reason: "rule '\(rule.name)' requires approval for \(action.type)")
                case .allow:
                    break
                }
            }
        }

        // 3. Domain allowlist
        guard allowlist.isAllowed(domain: action.domain) else {
            return .deny(
                reason: "domain '\(action.domain.rawValue)' not in capability allowlist",
                code: .domainDisabled
            )
        }

        // 4. Risk evaluation → sandbox routing
        let riskLevel = RiskEvaluator.evaluate(action: action)
        if riskLevel >= .elevated {
            return .sandbox(
                reason: "risk level \(riskLevel) requires sandbox for \(action.type)",
                riskLevel: riskLevel
            )
        }

        return .allow(reason: "policy passed", riskLevel: riskLevel)
    }

    // ── Legacy compatibility ────────────────────────────
    //
    // Existing consumers that call allow() -> Bool continue
    // to work. New code should use evaluate() -> PolicyDecision.

    public func allow(action: ActionIntent) -> Bool {
        let decision = evaluate(action: action)
        if !decision.allowed {
            print("[policy] Blocked: \(action.type) — \(decision.reason)")
        }
        return decision.allowed
    }

    // ── Risk evaluation ─────────────────────────────────

    public func requiresSandbox(action: ActionIntent) -> Bool {
        let decision = evaluate(action: action)
        return decision.requiresSandbox
    }

    // ── Rule management ─────────────────────────────

    public func addRule(_ rule: PolicyRule) {
        rules.append(rule)
    }

    private func loadDefaultRules() {
        // Block dangerous actions by default
        rules.append(PolicyRule(
            name: "block-force-push",
            pattern: "git_force_push",
            decision: .block
        ))
        rules.append(PolicyRule(
            name: "block-system-file-write",
            pattern: "write_system_file",
            decision: .block
        ))
        rules.append(PolicyRule(
            name: "approval-destructive-file",
            pattern: "delete_file",
            decision: .requireApproval
        ))
        // Block free-form shell strings
        rules.append(PolicyRule(
            name: "block-arbitrary-shell",
            pattern: "execute_arbitrary",
            decision: .block
        ))
    }
}

// ─────────────────────────────────────────────────────────
// PolicyRule
// ─────────────────────────────────────────────────────────

public struct PolicyRule {

    public enum Decision {
        case allow
        case block
        case requireApproval
    }

    public let name: String
    public let pattern: String
    public let decision: Decision

    public init(name: String, pattern: String, decision: Decision) {
        self.name = name
        self.pattern = pattern
        self.decision = decision
    }

    public func matches(action: ActionIntent) -> Bool {
        return action.type == pattern
    }
}

// ─────────────────────────────────────────────────────────
// CapabilityAllowlist — which domains are active
// ─────────────────────────────────────────────────────────

public struct CapabilityAllowlist {

    private var allowed: Set<ActionDomain> = [
        .system,
        .tool,
        .code,
    ]

    public init() {}

    public func isAllowed(domain: ActionDomain) -> Bool {
        return allowed.contains(domain)
    }

    public mutating func enable(_ domain: ActionDomain) {
        allowed.insert(domain)
    }

    public mutating func disable(_ domain: ActionDomain) {
        allowed.remove(domain)
    }
}

// ─────────────────────────────────────────────────────────
// RiskEvaluator — score action risk
// ─────────────────────────────────────────────────────────

public enum RiskLevel: Int, Comparable, Sendable {
    case safe = 0
    case low = 1
    case elevated = 2
    case high = 3
    case critical = 4

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct RiskEvaluator {

    public static func evaluate(action: ActionIntent) -> RiskLevel {

        // Sandbox-required actions
        let elevated: Set<String> = [
            "shell_command", "install_deps", "run_tests_untrusted",
            "browser_job_untrusted"
        ]

        let high: Set<String> = [
            "delete_file", "git_push", "network_request_external"
        ]

        let critical: Set<String> = [
            "git_force_push", "write_system_file", "execute_arbitrary"
        ]

        if critical.contains(action.type) { return .critical }
        if high.contains(action.type) { return .high }
        if elevated.contains(action.type) { return .elevated }

        return .safe
    }
}
