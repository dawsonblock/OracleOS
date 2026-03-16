import Foundation

// ─────────────────────────────────────────────────────────
// IntentRouter — maps high-level intents to execution lanes
//
// Routing rules:
//   • OS/UI intents → HostAutomation / Observation
//   • Code intents  → CodeIntelligence / Repair
//   • Browser intents → BrowserAutomation
//   • Search intents → Search layer + sidecars
//   • Risky intents  → Sandbox lane
// ─────────────────────────────────────────────────────────

public final class IntentRouter {

    public enum Lane {
        case local
        case sandbox
        case browser
        case hostUI
        case codeIntelligence
        case search
    }

    public init() {}

    public func route(action: ActionIntent, policy: PolicyEngine) -> Lane {

        if policy.requiresSandbox(action: action) {
            return .sandbox
        }

        switch action.domain {
        case .host:
            return .hostUI
        case .browser:
            return .browser
        case .code:
            return .codeIntelligence
        case .search:
            return .search
        case .system, .tool:
            return .local
        }
    }
}
