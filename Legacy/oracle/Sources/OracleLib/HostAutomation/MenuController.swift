import Foundation

// ─────────────────────────────────────────────────────────
// MenuController — navigate app menus via Accessibility (Phase 8)
// ─────────────────────────────────────────────────────────

public final class MenuController {

    public init() {}

    public func clickMenuItem(app: String, path: [String]) -> ExecutionResult {
        print("[menu-ctrl] Would click: \(app) → \(path.joined(separator: " > "))")
        return ExecutionResult(success: false, detail: "not connected", actionID: UUID().uuidString)
    }

    public func listMenuItems(app: String) -> [String] {
        // Phase 8: AXUIElement menu bar traversal
        return []
    }
}
