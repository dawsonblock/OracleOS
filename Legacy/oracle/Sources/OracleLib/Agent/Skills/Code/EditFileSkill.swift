import Foundation

// ─────────────────────────────────────────────────────────
// EditFileSkill — resolve an edit-file code intent
// ─────────────────────────────────────────────────────────

public struct EditFileSkill: CodeSkill {

    public let name = "edit_file"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let path = parameters["path"] ?? goal

        let intent = CodeSkillSupport.shellIntent(
            name: "edit_file",
            workspaceRoot: root,
            command: "edit",
            extra: ["path": path]
        )

        return SkillResolution(intent: intent, notes: ["target: \(path)"])
    }
}
