import Foundation

// ─────────────────────────────────────────────────────────
// ParseBuildFailureSkill — extract first error from build output
// ─────────────────────────────────────────────────────────

public struct ParseBuildFailureSkill: CodeSkill {

    public let name = "parse_build_failure"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let output = parameters["output"] ?? goal

        // Extract the first line containing "error:" as the primary diagnostic.
        let errorLine = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first(where: { $0.contains("error:") })
            .map(String.init) ?? "build failed (no error line found)"

        let intent = ActionIntent(
            type: "parse_build_failure",
            domain: .code,
            parameters: [
                "errorLine": errorLine,
                "rawOutput": String(output.prefix(512))
            ]
        )

        return SkillResolution(intent: intent, notes: ["first error: \(errorLine)"])
    }
}
