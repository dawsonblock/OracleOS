import Foundation

// ─────────────────────────────────────────────────────────
// ShellTool — policy-controlled shell execution
//
// All commands route through ActionRegistry → VerifiedActionExecutor.
// Direct Process() calls are forbidden outside this handler.
//
// INVARIANT: No `zsh -c` / `bash -c` / free-form shell strings.
//            Every invocation uses a typed CommandSpec with an
//            explicit executable URL and argument array.
//
// Blueprint ref: Gate 1, §1.4 — "ShellTool uses typed Process()"
// ─────────────────────────────────────────────────────────

public final class ShellTool {

    /// Allowlist of safe commands. Anything not listed is rejected.
    private static let allowedCommands: Set<String> = [
        "ls", "cat", "head", "tail", "wc", "grep", "find",
        "echo", "pwd", "date", "whoami", "uname",
        "swift", "swiftc", "xcodebuild",
        "git",
    ]

    /// Environment variables safe to pass through to child processes.
    private static let safeEnvVars: [String] = [
        "PATH", "HOME", "USER", "LANG", "TERM",
        "DEVELOPER_DIR", "SDKROOT",
    ]

    public static func register(in registry: ActionRegistry) {

        registry.register("shell_command") { action in
            guard let command = action.parameters["command"] else {
                return ExecutionResult(success: false, detail: "missing command parameter", actionID: action.id)
            }

            // Parse command into binary + arguments (no shell interpretation)
            let parts = command.split(separator: " ").map(String.init)
            guard let binary = parts.first else {
                return ExecutionResult(
                    success: false,
                    detail: "empty command",
                    actionID: action.id
                )
            }

            guard allowedCommands.contains(binary) else {
                return ExecutionResult(
                    success: false,
                    detail: "shell command not in allowlist: \(binary)",
                    actionID: action.id
                )
            }

            // Build a typed CommandSpec — no free-form shell strings
            let spec = CommandSpec(
                category: .custom,
                executable: binary,
                arguments: Array(parts.dropFirst()),
                workspaceRoot: action.parameters["cwd"] ?? FileManager.default.currentDirectoryPath,
                summary: "shell: \(binary)",
                allowlistedEnvVars: safeEnvVars,
                timeout: 30.0
            )

            // Resolve the executable URL through CommandSpec
            guard let executableURL = spec.resolvedExecutableURL() else {
                return ExecutionResult(
                    success: false,
                    detail: "cannot resolve executable path for: \(binary)",
                    actionID: action.id
                )
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = spec.arguments
            process.environment = spec.filteredEnvironment()

            if let cwd = action.parameters["cwd"] {
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let success = process.terminationStatus == 0

                return ExecutionResult(
                    success: success,
                    detail: output.trimmingCharacters(in: .whitespacesAndNewlines),
                    actionID: action.id
                )
            } catch {
                return ExecutionResult(
                    success: false,
                    detail: "shell exec failed: \(error.localizedDescription)",
                    actionID: action.id
                )
            }
        }
    }
}
