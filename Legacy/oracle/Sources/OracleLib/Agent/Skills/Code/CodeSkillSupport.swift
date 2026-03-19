import Foundation

// ─────────────────────────────────────────────────────────
// CodeSkillSupport — shared utilities for Code skills
//
// Provides workspace validation and canonical ActionIntent
// construction so each CodeSkill stays focused on logic.
// ─────────────────────────────────────────────────────────

public enum CodeSkillSupport {

    // MARK: - Validation

    /// Returns the workspace root or throws `.missingWorkspace`.
    public static func requireWorkspaceRoot(_ root: String?) throws -> String {
        guard let root = root, !root.isEmpty else {
            throw CodeSkillResolutionError.missingWorkspace
        }
        return root
    }

    // MARK: - Intent construction

    /// Builds a shell-command `ActionIntent` for a code skill.
    public static func shellIntent(
        name: String,
        domain: ActionDomain = .code,
        workspaceRoot: String,
        command: String,
        args: [String] = [],
        extra: [String: String] = [:]
    ) -> ActionIntent {
        var params: [String: String] = [
            "workspaceRoot": workspaceRoot,
            "command": command
        ]
        if !args.isEmpty {
            params["args"] = args.joined(separator: " ")
        }
        for (k, v) in extra { params[k] = v }
        return ActionIntent(type: name, domain: domain, parameters: params)
    }

    /// Builds a `git` command `ActionIntent` routed to `.tool`.
    public static func gitIntent(
        name: String,
        workspaceRoot: String,
        args: [String],
        extra: [String: String] = [:]
    ) -> ActionIntent {
        shellIntent(
            name: name,
            domain: .tool,
            workspaceRoot: workspaceRoot,
            command: "git",
            args: args,
            extra: extra
        )
    }
}
