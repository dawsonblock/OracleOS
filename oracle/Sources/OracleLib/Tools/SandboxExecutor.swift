import Foundation

// ─────────────────────────────────────────────────────────
// SandboxExecutor — adapter to OpenSandbox sidecar
//
// Risky operations route here instead of executing locally.
// Connects to: sidecars/sandbox/ (POST /execute, /run_tests, etc.)
//
// R4: GraphStore remains truth — sandbox results feed back
// through the executor and trace pipeline.
//
// Constraints:
//   • Max concurrent sandbox sessions: 4
//   • Per-command timeout ceiling: 300s
//   • Output truncation: 8KB
//   • Blocked command prefixes enforced locally
// ─────────────────────────────────────────────────────────

public final class SandboxExecutor {

    private let baseURL: String

    // ── Resource bounds ─────────────────────────────────
    public static let maxConcurrent = 4
    public static let maxTimeoutSeconds = 300
    public static let maxOutputBytes = 8192

    private var activeSessions = 0
    private let sessionLock = NSLock()

    // ── Blocked command prefixes (defense-in-depth) ─────
    private static let blockedPrefixes: [String] = [
        "rm -rf /",
        "mkfs",
        "dd if=/dev/zero",
        ":(){ :|:",          // fork bomb
        "chmod -R 777 /",
        "curl | sh",
        "wget | sh",
    ]

    public init(baseURL: String = "http://localhost:8080") {
        self.baseURL = baseURL
    }

    // ── Execute through sandbox ─────────────────────────

    private let http = HTTPClient(timeout: 60)

    public func run(action: ActionIntent) -> ExecutionResult {

        let command = action.parameters["command"] ?? ""
        let workspace = action.parameters["workspace"] ?? "/tmp/sandbox"
        let rawTimeout = Int(action.parameters["timeout"] ?? "60") ?? 60
        let timeout = min(rawTimeout, SandboxExecutor.maxTimeoutSeconds)

        // 1. Block dangerous commands locally before sidecar
        if let blocked = SandboxExecutor.isBlocked(command: command) {
            print("[sandbox] BLOCKED dangerous command: \(blocked)")
            return ExecutionResult(
                success: false,
                detail: "BLOCKED by sandbox policy: command matches blocked pattern '\(blocked)'",
                executedThroughExecutor: true,
                actionID: action.id
            )
        }

        // 2. Enforce concurrency limit
        sessionLock.lock()
        guard activeSessions < SandboxExecutor.maxConcurrent else {
            sessionLock.unlock()
            print("[sandbox] REJECTED: concurrency limit reached (\(SandboxExecutor.maxConcurrent))")
            return ExecutionResult(
                success: false,
                detail: "sandbox concurrency limit reached (\(SandboxExecutor.maxConcurrent) active)",
                executedThroughExecutor: true,
                actionID: action.id
            )
        }
        activeSessions += 1
        sessionLock.unlock()

        defer {
            sessionLock.lock()
            activeSessions -= 1
            sessionLock.unlock()
        }

        print("[sandbox] Executing in sandbox: \(command) (timeout: \(timeout)s)")

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

        // 3. Truncate output to bound
        let truncated = SandboxExecutor.truncate(detail, maxBytes: SandboxExecutor.maxOutputBytes)

        return ExecutionResult(
            success: sandboxSuccess,
            detail: truncated.isEmpty ? "sandbox completed (no output)" : truncated,
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

    // ── Static helpers ──────────────────────────────────

    public static func isBlocked(command: String) -> String? {
        let lower = command.lowercased().trimmingCharacters(in: .whitespaces)
        for prefix in blockedPrefixes {
            if lower.hasPrefix(prefix) || lower.contains(prefix) {
                return prefix
            }
        }
        return nil
    }

    public static func truncate(_ text: String, maxBytes: Int) -> String {
        guard text.utf8.count > maxBytes else { return text }
        let truncated = String(text.utf8.prefix(maxBytes))!
        return truncated + "\n... [output truncated at \(maxBytes) bytes]"
    }
}
