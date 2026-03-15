import Foundation

// ─────────────────────────────────────────────────────────
// ShellTool — policy-controlled shell execution
//
// All commands route through ActionRegistry → VerifiedActionExecutor.
// Direct Process() calls are forbidden outside this handler.
// ─────────────────────────────────────────────────────────

public final class ShellTool {

    /// Allowlist of safe commands. Anything not listed is rejected.
    private static let allowedCommands: Set<String> = [
        "ls", "cat", "head", "tail", "wc", "grep", "find",
        "echo", "pwd", "date", "whoami", "uname",
        "swift", "swiftc", "xcodebuild",
        "git",
    ]

    public static func register(in registry: ActionRegistry) {

        registry.register("shell_command") { action in
            guard let command = action.parameters["command"] else {
                return ExecutionResult(success: false, detail: "missing command parameter", actionID: action.id)
            }

            let parts = command.split(separator: " ", maxSplits: 1)
            let binary = String(parts.first ?? "")

            guard allowedCommands.contains(binary) else {
                return ExecutionResult(
                    success: false,
                    detail: "shell command not in allowlist: \(binary)",
                    actionID: action.id
                )
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

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
