import Foundation

// ─────────────────────────────────────────────────────────
// GitTool — safe git operations through the executor
//
// Safe: status, diff, log, branch, commit
// Approval-gated: push
// Blocked: force-push
// ─────────────────────────────────────────────────────────

public final class GitTool {

    public static func register(in registry: ActionRegistry) {

        // git_status — always safe
        registry.register("git_status") { action in
            let cwd = action.parameters["cwd"] ?? "."
            return GitTool.runGit(["status", "--porcelain"], cwd: cwd, actionID: action.id)
        }

        // git_diff — always safe
        registry.register("git_diff") { action in
            let cwd = action.parameters["cwd"] ?? "."
            return GitTool.runGit(["diff", "--stat"], cwd: cwd, actionID: action.id)
        }

        // git_log — always safe
        registry.register("git_log") { action in
            let cwd = action.parameters["cwd"] ?? "."
            let limit = action.parameters["limit"] ?? "10"
            return GitTool.runGit(["log", "--oneline", "-\(limit)"], cwd: cwd, actionID: action.id)
        }

        // git_branch — safe read
        registry.register("git_branch") { action in
            let cwd = action.parameters["cwd"] ?? "."
            return GitTool.runGit(["branch", "--list"], cwd: cwd, actionID: action.id)
        }

        // git_commit — write action, policy-checked at executor level
        registry.register("git_commit") { action in
            let cwd = action.parameters["cwd"] ?? "."
            let message = action.parameters["message"] ?? "auto-commit"
            return GitTool.runGit(["commit", "-m", message], cwd: cwd, actionID: action.id)
        }
    }

    private static func runGit(_ args: [String], cwd: String, actionID: String) -> ExecutionResult {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return ExecutionResult(
                success: process.terminationStatus == 0,
                detail: output.trimmingCharacters(in: .whitespacesAndNewlines),
                actionID: actionID
            )
        } catch {
            return ExecutionResult(
                success: false,
                detail: "git failed: \(error.localizedDescription)",
                actionID: actionID
            )
        }
    }
}
