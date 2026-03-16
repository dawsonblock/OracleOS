import Foundation

// ─────────────────────────────────────────────────────────
// RunTestsSkill — resolve a test-runner code intent
// ─────────────────────────────────────────────────────────

public struct RunTestsSkill: CodeSkill {

    public let name = "run_tests"

    public init() {}

    public func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution {
        let root = try CodeSkillSupport.requireWorkspaceRoot(workspaceRoot)
        let testCmd = parameters["testCommand"] ?? "swift test"
        let filter = parameters["filter"] ?? ""

        var extra: [String: String] = [:]
        if !filter.isEmpty { extra["filter"] = filter }

        let intent = CodeSkillSupport.shellIntent(
            name: "run_tests",
            workspaceRoot: root,
            command: testCmd,
            extra: extra
        )

        return SkillResolution(intent: intent, notes: ["cmd: \(testCmd)"])
    }
}
