import Foundation

// ─────────────────────────────────────────────────────────
// RunFormatterSkill — resolve a code-formatter intent
// ─────────────────────────────────────────────────────────

public struct RunFormatterSkill: CodeSkill {

    public let name = "run_formatter"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let formatter = parameters["formatter"] ?? "swift-format"
        let path = parameters["path"] ?? "."

        let intent = CodeSkillSupport.shellIntent(
            name: "run_formatter",
            workspaceRoot: root,
            command: formatter,
            args: ["--in-place", "-r", path],
            extra: ["path": path]
        )

        return SkillResolution(intent: intent, notes: ["formatter: \(formatter)"])
    }
}
