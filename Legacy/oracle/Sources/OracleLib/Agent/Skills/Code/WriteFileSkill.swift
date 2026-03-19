import Foundation

// ─────────────────────────────────────────────────────────
// WriteFileSkill — resolve a write-file code intent
// ─────────────────────────────────────────────────────────

public struct WriteFileSkill: CodeSkill {

    public let name = "write_file"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let path = parameters["path"] ?? goal
        let content = parameters["content"] ?? ""

        let intent = CodeSkillSupport.shellIntent(
            name: "write_file",
            workspaceRoot: root,
            command: "write",
            extra: ["path": path, "content": content]
        )

        return SkillResolution(intent: intent, notes: ["path: \(path)"])
    }
}
