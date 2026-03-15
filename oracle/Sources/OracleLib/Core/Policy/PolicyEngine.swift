import Foundation

// ─────────────────────────────────────────────────────────
// PolicyEngine — gating authority for all actions
//
// Controls: filesystem, network, sandbox usage, system APIs,
// macOS services, browser automation.
//
// Ambiguous policy states fail closed.
// ─────────────────────────────────────────────────────────

public final class PolicyEngine {

    private var rules: [PolicyRule] = []
    private var allowlist = CapabilityAllowlist()

    public init() {
        loadDefaultRules()
    }

    // ── Core gate ───────────────────────────────────────

    public func allow(action: ActionIntent) -> Bool {

        // Check explicit blocks first
        for rule in rules {
            if rule.matches(action: action) {
                if rule.decision == .block {
                    print("[policy] Blocked: \(action.type) — rule: \(rule.name)")
                    return false
                }
                if rule.decision == .requireApproval {
                    print("[policy] Approval required for: \(action.type)")
                    // Phase 10+: interactive approval gate
                    return false
                }
            }
        }

        // Check capability allowlist
        guard allowlist.isAllowed(domain: action.domain) else {
            print("[policy] Domain not in allowlist: \(action.domain.rawValue)")
            return false
        }

        return true
    }

    // ── Risk evaluation ─────────────────────────────────

    public func requiresSandbox(action: ActionIntent) -> Bool {
        let riskLevel = RiskEvaluator.evaluate(action: action)
        return riskLevel >= .elevated
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

public enum RiskLevel: Int, Comparable {
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
