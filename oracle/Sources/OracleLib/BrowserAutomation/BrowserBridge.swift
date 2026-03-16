import Foundation

// ─────────────────────────────────────────────────────────
// BrowserBridge — WebSocket / HTTP connection to browser sidecar
//
// Phase 7: implement real WebSocket frame protocol.
// ─────────────────────────────────────────────────────────

public final class BrowserBridge {

    private let debuggerURL: String
    private let http = HTTPClient(timeout: 10)

    public init(sidecarURL: String = "http://localhost:9222") {
        self.debuggerURL = sidecarURL
    }

    /// Send a command to Chrome DevTools Protocol and return the result.
    public func send(command: String, params: [String: String]) -> String? {
        print("[browser-bridge] \(command) → \(params)")

        // Step 1: Get active page target
        let targetsResp = http.get(url: "\(debuggerURL)/json")
        guard targetsResp.success else {
            print("[browser-bridge] CDP not reachable at \(debuggerURL)")
            return nil
        }

        // Map high-level commands to CDP-compatible HTTP calls
        switch command {
        case "navigate":
            guard let url = params["url"] else { return nil }
            // Use CDP Page.navigate via the debug endpoint
            let resp = http.post(
                url: "\(debuggerURL)/json/new?\(url)",
                json: [:]
            )
            return resp.success ? "navigated to \(url)" : nil

        case "snapshot":
            // Return page list as snapshot placeholder
            return targetsResp.body

        case "click", "type":
            // These require WebSocket CDP — return instruction for now
            return "CDP command \(command) requires WebSocket session (Phase 7+)"

        default:
            return "unknown command: \(command)"
        }
    }

    public func isConnected() -> Bool {
        return http.isReachable(baseURL: debuggerURL)
    }

    /// List all CDP targets (browser tabs).
    public func listTargets() -> [[String: Any]] {
        let resp = http.get(url: "\(debuggerURL)/json")
        guard resp.success, let data = resp.body.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr
    }
}
