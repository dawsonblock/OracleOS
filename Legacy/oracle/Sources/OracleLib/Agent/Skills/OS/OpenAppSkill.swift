import Foundation

// ─────────────────────────────────────────────────────────
// OpenAppSkill — focus or launch an application
// ─────────────────────────────────────────────────────────

public struct OpenAppSkill: Skill {

    public let name = "open_app"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let appName = parameters["app"] ?? query

        let intent = ActionIntent(
            type: "open_app",
            domain: .host,
            parameters: [
                "app": appName
            ]
        )

        return SkillResolution(intent: intent, confidence: 1.0)
    }
}
