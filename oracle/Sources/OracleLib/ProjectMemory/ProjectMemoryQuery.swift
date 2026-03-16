import Foundation

public enum ProjectMemoryQuery {
    public static func relevantRecords(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> [ProjectMemoryRef] {
        planningSignals(goalDescription: goalDescription, snapshot: snapshot, store: store, limit: limit).refs
    }

    public static func architectureDecisions(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> [ProjectMemoryRecord] {
        records(goalDescription: goalDescription, snapshot: snapshot, store: store, kind: .architectureDecision, limit: limit)
    }

    public static func knownProblems(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> [ProjectMemoryRecord] {
        records(goalDescription: goalDescription, snapshot: snapshot, store: store, kind: .openProblem, limit: limit)
    }

    public static func rejectedApproaches(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> [ProjectMemoryRecord] {
        records(goalDescription: goalDescription, snapshot: snapshot, store: store, kind: .rejectedApproach, limit: limit)
    }

    public static func knownGoodPatterns(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> [ProjectMemoryRecord] {
        records(goalDescription: goalDescription, snapshot: snapshot, store: store, kind: .knownGoodPattern, limit: limit)
    }

    public static func risks(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> [ProjectMemoryRecord] {
        records(goalDescription: goalDescription, snapshot: snapshot, store: store, kind: .risk, limit: limit)
    }

    public static func planningSignals(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, limit: Int = 6) -> ProjectMemoryPlanningSignals {
        ProjectMemoryPlanningSignals(
            architectureDecisions: architectureDecisions(goalDescription: goalDescription, snapshot: snapshot, store: store, limit: limit),
            openProblems: knownProblems(goalDescription: goalDescription, snapshot: snapshot, store: store, limit: limit),
            rejectedApproaches: rejectedApproaches(goalDescription: goalDescription, snapshot: snapshot, store: store, limit: limit),
            knownGoodPatterns: knownGoodPatterns(goalDescription: goalDescription, snapshot: snapshot, store: store, limit: limit),
            risks: risks(goalDescription: goalDescription, snapshot: snapshot, store: store, limit: limit)
        )
    }

    private static func records(goalDescription: String, snapshot: RepositorySnapshot, store: ProjectMemoryStore, kind: ProjectMemoryKind, limit: Int) -> [ProjectMemoryRecord] {
        let text = [goalDescription, snapshot.activeBranch, snapshot.files.map(\.path).joined(separator: " ")]
            .compactMap { $0 }
            .joined(separator: " ")
        let refs = store.query(text: text, modules: snapshot.files.map { ArchitectureModuleGraph.moduleName(for: $0.path) }, kinds: [kind], limit: limit)
        let recordsByPath = Dictionary(uniqueKeysWithValues: store.allRecords(includeEpisodeResidue: false).map { ($0.path, $0) })
        return refs.compactMap { ref in recordsByPath[ref.path] }
    }
}
