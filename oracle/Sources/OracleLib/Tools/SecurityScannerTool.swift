import Foundation

// ─────────────────────────────────────────────────────────
// SecurityScannerTool — RAPTOR-inspired patterns (Phase 23)
//
// Security scans run as bounded tools or experiments,
// not as hidden planner behavior.
// ─────────────────────────────────────────────────────────

public final class SecurityScannerTool {

    public static func register(in registry: ActionRegistry) {

        registry.register("security_scan") { action in
            let target = action.parameters["target"] ?? "."
            print("[security] Scan requested for: \(target)")
            return ExecutionResult(
                success: false,
                detail: "security scanner not yet connected",
                actionID: action.id
            )
        }
    }
}
