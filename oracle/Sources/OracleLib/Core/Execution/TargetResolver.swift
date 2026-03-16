import Foundation

// ─────────────────────────────────────────────────────────
// TargetResolver — resolve abstract targets to concrete handles
//
// The planner emits abstract targets like:
//   Click(Button("Send"))
//   Type(Input("Search"), "hello")
//
// TargetResolver resolves those to concrete AX/DOM/file handles
// that the executor can act on.
//
// Resolution priority:
//   1. DOM ID (browser — most reliable)
//   2. Accessibility identifier (native apps)
//   3. Role + label match
//   4. Vision fallback (Phase 6+)
// ─────────────────────────────────────────────────────────

public struct ResolvedTarget {

    public let id: String
    public let method: ResolutionMethod
    public let confidence: Double

    public enum ResolutionMethod: String {
        case domID
        case accessibilityID
        case roleLabel
        case vision
        case path     // filesystem
        case direct   // no resolution needed
    }
}

public final class TargetResolver {

    public init() {}

    public func resolve(action: ActionIntent) -> ResolvedTarget {
        // Default: direct (no UI resolution needed for system actions)
        return ResolvedTarget(
            id: action.id,
            method: .direct,
            confidence: 1.0
        )
    }
}
