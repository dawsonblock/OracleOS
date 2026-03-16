import Foundation

// ─────────────────────────────────────────────────────────
// ReadFileSkill — resolve a file path from world state
// ─────────────────────────────────────────────────────────

public struct ReadFileSkill: Skill {

    public let name = "read_file"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        // Prefer explicit path parameter; fall back to query
        let path = parameters["path"] ?? query

        let intent = ActionIntent(
            type: "read_file",
            domain: .host,
            parameters: [
                "path": path,
                "app": worldSnapshot.activeApplication ?? "Finder"
            ]
        )

        return SkillResolution(
            intent: intent,
            confidence: 1.0,
            notes: ["path: \(path)"]
        )
    }
}
