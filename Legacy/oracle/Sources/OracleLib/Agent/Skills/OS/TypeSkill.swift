import Foundation

// ─────────────────────────────────────────────────────────
// TypeSkill — resolve a text input target and type into it
// ─────────────────────────────────────────────────────────

public struct TypeSkill: Skill {

    public let name = "type"

    public init() {}

    public func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let text = parameters["text"] ?? ""

        guard let match = OSTargetResolver.resolve(
            query: query,
            role: "textField",
            snapshot: worldSnapshot
        ) else {
            throw SkillResolutionError.noCandidate("type target not found: \(query)")
        }

        let intent = ActionIntent(
            type: "type",
            domain: .host,
            parameters: [
                "query": query,
                "targetID": match.elementID,
                "text": text,
                "app": worldSnapshot.activeApplication ?? "unknown"
            ]
        )

        return SkillResolution(
            intent: intent,
            resolvedTargetID: match.elementID,
            confidence: match.confidence
        )
    }
}
