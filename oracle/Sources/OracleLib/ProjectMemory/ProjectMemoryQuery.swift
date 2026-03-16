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
        let modules = searchModules(for: snapshot)
        let queryTexts = searchTexts(for: goalDescription)
        var refsByPath: [String: ProjectMemoryRef] = [:]

        for queryText in queryTexts {
            for ref in store.query(text: queryText, modules: modules, kinds: [kind], limit: limit) {
                refsByPath[ref.path] = ref
            }
            if refsByPath.count >= limit { break }
        }

        if refsByPath.isEmpty {
            for ref in store.query(text: "", modules: modules, kinds: [kind], limit: limit) {
                refsByPath[ref.path] = ref
            }
        }

        let recordsByPath = Dictionary(uniqueKeysWithValues: store.allRecords(includeEpisodeResidue: false).map { ($0.path, $0) })
        return Array(refsByPath.values)
            .sorted { lhs, rhs in
                if lhs.path == rhs.path { return lhs.id < rhs.id }
                return lhs.path < rhs.path
            }
            .prefix(limit)
            .compactMap { ref in recordsByPath[ref.path] }
    }

    private static func searchTexts(for goalDescription: String) -> [String] {
        let trimmed = goalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [""] }

        let keywords = trimmed
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var queries: [String] = [trimmed]
        queries.append(contentsOf: keywords)
        return Array(NSOrderedSet(array: queries)) as? [String] ?? queries
    }

    private static func searchModules(for snapshot: RepositorySnapshot) -> [String] {
        let modules = snapshot.files.flatMap { file in
            var candidates = [ArchitectureModuleGraph.moduleName(for: file.path)]
            let components = file.path.split(separator: "/").map(String.init)
            if components.first == "Sources", components.count >= 2 {
                candidates.append(components[1])
            }
            return candidates
        }
        return Array(NSOrderedSet(array: modules)) as? [String] ?? modules
    }
}
