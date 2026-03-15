import Foundation

// ─────────────────────────────────────────────────────────
// SearchCodeSkill — resolve a code-search intent
// ─────────────────────────────────────────────────────────

public struct SearchCodeSkill: CodeSkill {

    public let name = "search_code"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let query = parameters["query"] ?? goal
        let ext = parameters["fileExtension"] ?? ""

        var extra: [String: String] = ["query": query]
        if !ext.isEmpty { extra["fileExtension"] = ext }

        let intent = CodeSkillSupport.shellIntent(
            name: "search_code",
            domain: .search,
            workspaceRoot: root,
            command: "grep",
            args: ["-r", "--include=*\(ext.isEmpty ? "" : ".\(ext)")", query, root],
            extra: extra
        )

        return SkillResolution(intent: intent, notes: ["query: \(query)"])
    }
}
