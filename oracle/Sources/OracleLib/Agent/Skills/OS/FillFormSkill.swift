import Foundation

// ─────────────────────────────────────────────────────────
// FillFormSkill — type into a form field target
// ─────────────────────────────────────────────────────────

public struct FillFormSkill: Skill {

    public let name = "fill_form"

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
            throw SkillResolutionError.noCandidate("form field not found: \(query)")
        }

        let intent = ActionIntent(
            type: "fill_form",
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
