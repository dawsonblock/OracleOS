import Foundation

// ─────────────────────────────────────────────────────────
// BrowserController — orchestrate browser automation (Phase 7)
//
// All browser actions flow through VerifiedActionExecutor.
// BrowserController owns: page lifecycle, DOM snapshot,
// text reduction, target resolution.
//
// Connects to the page-agent sidecar or Peekaboo for
// real browser control.
// ─────────────────────────────────────────────────────────

public final class BrowserController {

    private let bridge: BrowserBridge
    private let domIndexer: DOMIndexer
    private let textReducer: PageTextReducer

    public init(
        bridge: BrowserBridge = BrowserBridge(),
        domIndexer: DOMIndexer = DOMIndexer(),
        textReducer: PageTextReducer = PageTextReducer()
    ) {
        self.bridge = bridge
        self.domIndexer = domIndexer
        self.textReducer = textReducer
    }

    // ── High-level actions ──────────────────────────────

    public func navigate(url: String) -> ExecutionResult {
        let result = bridge.send(command: "navigate", params: ["url": url])
        return ExecutionResult(
            success: result != nil,
            detail: result ?? "bridge unavailable",
            actionID: UUID().uuidString
        )
    }

    public func click(selector: String) -> ExecutionResult {
        let result = bridge.send(command: "click", params: ["selector": selector])
        return ExecutionResult(
            success: result != nil,
            detail: result ?? "bridge unavailable",
            actionID: UUID().uuidString
        )
    }

    public func type(selector: String, text: String) -> ExecutionResult {
        let result = bridge.send(command: "type", params: ["selector": selector, "text": text])
        return ExecutionResult(
            success: result != nil,
            detail: result ?? "bridge unavailable",
            actionID: UUID().uuidString
        )
    }

    public func snapshot() -> PageSnapshot? {
        guard let html = bridge.send(command: "snapshot", params: [:]) else {
            return nil
        }
        return PageSnapshot(url: "unknown", html: html, timestamp: Date())
    }

    public func readableText() -> String {
        guard let snap = snapshot() else { return "" }
        return textReducer.reduce(html: snap.html)
    }

    // ── Register as tool actions ────────────────────────

    public static func register(in registry: ActionRegistry) {
        let controller = BrowserController()

        registry.register("browser_navigate") { action in
            let url = action.parameters["url"] ?? ""
            return controller.navigate(url: url)
        }

        registry.register("browser_click") { action in
            let sel = action.parameters["selector"] ?? ""
            return controller.click(selector: sel)
        }

        registry.register("browser_type") { action in
            let sel = action.parameters["selector"] ?? ""
            let text = action.parameters["text"] ?? ""
            return controller.type(selector: sel, text: text)
        }

        registry.register("browser_snapshot") { action in
            let text = controller.readableText()
            return ExecutionResult(
                success: !text.isEmpty,
                detail: text.isEmpty ? "no snapshot" : text,
                actionID: action.id
            )
        }
    }
}
