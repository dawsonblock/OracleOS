import Foundation

// ─────────────────────────────────────────────────────────
// GitBranchSkill — resolve a git-branch tool intent
// ─────────────────────────────────────────────────────────

public struct GitBranchSkill: CodeSkill {

    public let name = "git_branch"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let branch = parameters["branch"] ?? ""

        // If a branch name is provided, create/checkout it; otherwise show current branch.
        let args: [String] = branch.isEmpty
            ? ["branch", "--show-current"]
            : ["checkout", "-b", branch]

        let extra: [String: String] = branch.isEmpty ? [:] : ["branch": branch]

        let intent = CodeSkillSupport.gitIntent(
            name: "git_branch",
            workspaceRoot: root,
            args: args,
            extra: extra
        )

        return SkillResolution(intent: intent)
    }
}
