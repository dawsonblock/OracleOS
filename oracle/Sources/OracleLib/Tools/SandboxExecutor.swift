import Foundation

// ─────────────────────────────────────────────────────────
// SandboxExecutor — adapter to OpenSandbox sidecar
//
// Risky operations route here instead of executing locally.
// Connects to: sidecars/sandbox/ (POST /execute, /run_tests, etc.)
//
// GraphStore remains truth — sandbox results feed back through
// the executor and trace pipeline.
// ─────────────────────────────────────────────────────────

public final class SandboxExecutor {

    private let baseURL: String

    public init(baseURL: String = "http://localhost:8080") {
        self.baseURL = baseURL
    }

    // ── Execute through sandbox ─────────────────────

    private let http = HTTPClient(timeout: 60)

    public func run(action: ActionIntent) -> ExecutionResult {

        let command = action.parameters["command"] ?? ""
        let workspace = action.parameters["workspace"] ?? "/tmp/sandbox"
        let timeout = Int(action.parameters["timeout"] ?? "60") ?? 60

        print("[sandbox] Executing in sandbox: \(command)")

        let response = http.post(
            url: "\(baseURL)/execute",
            json: ["command": command, "workspace": workspace, "timeout": timeout],
            timeout: TimeInterval(timeout + 5)
        )

        guard response.success, let json = response.json else {
            return ExecutionResult(
                success: false,
                detail: "sandbox sidecar unreachable: \(response.error ?? "unknown")",
                executedThroughExecutor: true,
                actionID: action.id
            )
        }

        let sandboxSuccess = json["success"] as? Bool ?? false
        let stdout = json["stdout"] as? String ?? ""
        let stderr = json["stderr"] as? String ?? ""
        let detail = sandboxSuccess ? stdout : (stderr.isEmpty ? stdout : stderr)

        return ExecutionResult(
            success: sandboxSuccess,
            detail: detail.isEmpty ? "sandbox completed (no output)" : String(detail.prefix(4096)),
            executedThroughExecutor: true,
            actionID: action.id
        )
    }

    // ── Convenience methods ─────────────────────────────

    public func runTests(workspace: String, command: String = "swift test") -> ExecutionResult {
        let action = ActionIntent(
            type: "run_tests",
            domain: .code,
            parameters: ["workspace": workspace, "command": command]
        )
        return run(action: action)
    }

    public func installDeps(workspace: String, manifest: String) -> ExecutionResult {
        let action = ActionIntent(
            type: "install_deps",
            domain: .code,
            parameters: ["workspace": workspace, "manifest": manifest]
        )
        return run(action: action)
    }

    // ── Health check ────────────────────────────────────

    public func isAvailable() -> Bool {
        return http.isReachable(baseURL: baseURL)
    }
}
