import Foundation

// ─────────────────────────────────────────────────────────
// GitCommitSkill — resolve a git-commit tool intent
// ─────────────────────────────────────────────────────────

public struct GitCommitSkill: CodeSkill {

    public let name = "git_commit"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)

        guard let message = parameters["message"], !message.isEmpty else {
            throw CodeSkillResolutionError.noRelevantFiles("git_commit: commit message required")
        }

        let intent = CodeSkillSupport.gitIntent(
            name: "git_commit",
            workspaceRoot: root,
            args: ["commit", "-m", message],
            extra: ["message": message]
        )

        return SkillResolution(intent: intent, notes: ["msg: \(message)"])
    }
}
