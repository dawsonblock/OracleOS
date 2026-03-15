import Foundation

// ─────────────────────────────────────────────────────────
// NavigateURLSkill — navigate a browser to a URL
// ─────────────────────────────────────────────────────────

public struct NavigateURLSkill: Skill {

    public let name = "navigate_url"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let url = parameters["url"] ?? query

        guard !url.isEmpty else {
            throw SkillResolutionError.unsupportedOperation("navigate_url requires a URL")
        }

        let intent = ActionIntent(
            type: "navigate_url",
            domain: .browser,
            parameters: [
                "url": url,
                "app": worldSnapshot.focusedApp ?? "unknown"
            ]
        )

        return SkillResolution(intent: intent, confidence: 1.0)
    }
}
