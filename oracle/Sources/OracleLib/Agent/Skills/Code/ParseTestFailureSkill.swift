import Foundation

// ─────────────────────────────────────────────────────────
// ParseTestFailureSkill — extract first failure from test output
// ─────────────────────────────────────────────────────────

public struct ParseTestFailureSkill: CodeSkill {

    public let name = "parse_test_failure"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let output = parameters["output"] ?? goal

        // Extract the first line flagging a FAILED test or assertion failure.
        let failedLine = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first(where: { $0.contains("FAILED") || $0.contains("XCTAssert") || $0.contains("failed:") })
            .map(String.init) ?? "test failed (no failure line found)"

        let intent = ActionIntent(
            type: "parse_test_failure",
            domain: .code,
            parameters: [
                "failedLine": failedLine,
                "rawOutput": String(output.prefix(512))
            ]
        )

        return SkillResolution(intent: intent, notes: ["first failure: \(failedLine)"])
    }
}
