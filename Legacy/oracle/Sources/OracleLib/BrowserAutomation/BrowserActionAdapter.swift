import Foundation

// ─────────────────────────────────────────────────────────
// BrowserActionAdapter — translate ActionIntent → browser commands
// ─────────────────────────────────────────────────────────

public final class BrowserActionAdapter {

    private let controller: BrowserController

    public init(controller: BrowserController = BrowserController()) {
        self.controller = controller
    }

    public func execute(action: ActionIntent) -> ExecutionResult {
        switch action.type {
        case "browser_navigate":
            return controller.navigate(url: action.parameters["url"] ?? "")
        case "browser_click":
            return controller.click(selector: action.parameters["selector"] ?? "")
        case "browser_type":
            return controller.type(
                selector: action.parameters["selector"] ?? "",
                text: action.parameters["text"] ?? ""
            )
        default:
            return ExecutionResult(
                success: false,
                detail: "unknown browser action: \(action.type)",
                actionID: action.id
            )
        }
    }
}
