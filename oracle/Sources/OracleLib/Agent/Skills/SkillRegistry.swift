import Foundation

// ─────────────────────────────────────────────────────────
// SkillRegistry — central lookup for OS + Code skills
//
// The registry is the single point of truth for available
// skills. OracleRuntime holds one instance, wired at init.
//
// Usage:
//   let registry = SkillRegistry.live()
//   if let skill = registry.get("click") { … }
//   if let codeSkill = registry.getCode("run_build") { … }
// ─────────────────────────────────────────────────────────

public final class SkillRegistry {

    private var skills: [String: any Skill] = [:]
    private var codeSkills: [String: any CodeSkill] = [:]

    public init() {}

    // MARK: - Registration

    public func register(_ skill: any Skill) {
        skills[skill.name] = skill
    }

    public func register(_ skill: any CodeSkill) {
        codeSkills[skill.name] = skill
    }

    // MARK: - Lookup

    public func get(_ name: String) -> (any Skill)? {
        skills[name]
    }

    public func getCode(_ name: String) -> (any CodeSkill)? {
        codeSkills[name]
    }

    // MARK: - Introspection

    public var allSkillNames: [String] {
        Array(skills.keys).sorted()
    }

    public var allCodeSkillNames: [String] {
        Array(codeSkills.keys).sorted()
    }

    public var totalCount: Int {
        skills.count + codeSkills.count
    }

    // MARK: - Factory

    /// Pre-populated registry with all built-in OS and Code skills.
    public static func live() -> SkillRegistry {
        let registry = SkillRegistry()

        // OS Skills
        registry.register(ClickSkill())
        registry.register(TypeSkill())
        registry.register(ScrollSkill())
        registry.register(OpenAppSkill())
        registry.register(SwitchWindowSkill())
        registry.register(NavigateURLSkill())
        registry.register(FillFormSkill())
        registry.register(ReadFileSkill())

        // Code Skills
        registry.register(EditFileSkill())
        registry.register(WriteFileSkill())
        registry.register(OpenFileInEditorSkill())
        registry.register(SearchCodeSkill())
        registry.register(RunBuildSkill())
        registry.register(RunTestsSkill())
        registry.register(RunFormatterSkill())
        registry.register(RunLinterSkill())
        registry.register(GitStatusSkill())
        registry.register(GitBranchSkill())
        registry.register(GitCommitSkill())
        registry.register(GitPushSkill())
        registry.register(ParseBuildFailureSkill())
        registry.register(ParseTestFailureSkill())

        return registry
    }
}
