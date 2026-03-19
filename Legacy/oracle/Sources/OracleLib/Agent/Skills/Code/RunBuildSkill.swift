import Foundation

// ─────────────────────────────────────────────────────────
// RunBuildSkill — resolve a build-command code intent
// ─────────────────────────────────────────────────────────

public struct RunBuildSkill: CodeSkill {

    public let name = "run_build"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let buildCmd = parameters["buildCommand"] ?? "swift build"

        let intent = CodeSkillSupport.shellIntent(
            name: "run_build",
            workspaceRoot: root,
            command: buildCmd,
            extra: ["goal": goal]
        )

        return SkillResolution(intent: intent, notes: ["cmd: \(buildCmd)"])
    }
}
