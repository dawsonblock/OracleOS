import Foundation

// ─────────────────────────────────────────────────────────
// RunLinterSkill — resolve a linter-run code intent
// ─────────────────────────────────────────────────────────

public struct RunLinterSkill: CodeSkill {

    public let name = "run_linter"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let linter = parameters["linter"] ?? "swiftlint"

        let intent = CodeSkillSupport.shellIntent(
            name: "run_linter",
            workspaceRoot: root,
            command: linter,
            extra: [:]
        )

        return SkillResolution(intent: intent, notes: ["linter: \(linter)"])
    }
}
