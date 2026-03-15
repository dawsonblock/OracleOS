import Foundation

// ─────────────────────────────────────────────────────────
// ClickSkill — resolve a click target against world state
// ─────────────────────────────────────────────────────────

public struct ClickSkill: Skill {

    public let name = "click"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        guard let match = OSTargetResolver.resolve(
            query: query,
            role: parameters["role"],
            snapshot: worldSnapshot
        ) else {
            throw SkillResolutionError.noCandidate("click target not found: \(query)")
        }

        let intent = ActionIntent(
            type: "click",
            domain: .host,
            parameters: [
                "query": query,
                "targetID": match.elementID,
                "app": worldSnapshot.focusedApp ?? "unknown"
            ]
        )

        return SkillResolution(
            intent: intent,
            resolvedTargetID: match.elementID,
            confidence: match.confidence
        )
    }
}
