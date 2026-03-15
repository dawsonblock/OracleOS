import Foundation

// ─────────────────────────────────────────────────────────
// SwitchWindowSkill — switch to a specific window by title
// ─────────────────────────────────────────────────────────

public struct SwitchWindowSkill: Skill {

    public let name = "switch_window"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let windowTitle = parameters["windowTitle"] ?? query
        let appName = parameters["app"] ?? worldSnapshot.activeApplication ?? "unknown"

        let intent = ActionIntent(
            type: "switch_window",
            domain: .host,
            parameters: [
                "app": appName,
                "windowTitle": windowTitle
            ]
        )

        return SkillResolution(intent: intent, confidence: 1.0)
    }
}
