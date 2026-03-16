import Foundation

// ─────────────────────────────────────────────────────────
// OpenFileInEditorSkill — resolve an open-in-editor intent
// ─────────────────────────────────────────────────────────

public struct OpenFileInEditorSkill: CodeSkill {

    public let name = "open_file_in_editor"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let path = parameters["path"] ?? goal

        let intent = CodeSkillSupport.shellIntent(
            name: "open_file_in_editor",
            domain: .host,
            workspaceRoot: root,
            command: "open",
            extra: ["path": path]
        )

        return SkillResolution(intent: intent, notes: ["file: \(path)"])
    }
}
