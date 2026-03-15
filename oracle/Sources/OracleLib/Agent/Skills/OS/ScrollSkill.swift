import Foundation

// ─────────────────────────────────────────────────────────
// ScrollSkill — emit a scroll action (no element resolution)
// ─────────────────────────────────────────────────────────

public struct ScrollSkill: Skill {

    public let name = "scroll"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let direction = parameters["direction"] ?? "down"
        let amount = parameters["amount"] ?? "1"

        let intent = ActionIntent(
            type: "scroll",
            domain: .host,
            parameters: [
                "direction": direction,
                "amount": amount,
                "app": worldSnapshot.activeApplication ?? "unknown"
            ]
        )

        return SkillResolution(intent: intent)
    }
}
