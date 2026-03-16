import Foundation

// ─────────────────────────────────────────────────────────
// GitStatusSkill — resolve a git-status tool intent
// ─────────────────────────────────────────────────────────

public struct GitStatusSkill: CodeSkill {

    public let name = "git_status"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)

        let intent = CodeSkillSupport.gitIntent(
            name: "git_status",
            workspaceRoot: root,
            args: ["status", "--short"]
        )

        return SkillResolution(intent: intent)
    }
}
