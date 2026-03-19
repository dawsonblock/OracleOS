import Foundation

// ─────────────────────────────────────────────────────────
// GitPushSkill — resolve a git-push tool intent
// ─────────────────────────────────────────────────────────

public struct GitPushSkill: CodeSkill {

    public let name = "git_push"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let remote = parameters["remote"] ?? "origin"
        let branch = parameters["branch"] ?? "HEAD"

        let intent = CodeSkillSupport.gitIntent(
            name: "git_push",
            workspaceRoot: root,
            args: ["push", remote, branch],
            extra: ["remote": remote, "branch": branch]
        )

        return SkillResolution(intent: intent)
    }
}
