import Foundation

// MARK: - PatternMemoryStore

/// Wraps `AppMemoryStore` to provide code-pattern bias queries.
public struct PatternMemoryStore {
    private let store: AppMemoryStore

    public init(store: AppMemoryStore) {
        self.store = store
    }

    /// The preferred fix path for a known error signature, scored by success history.
    public func preferredFixPath(errorSignature: String?, now: Date = Date()) -> String? {
        guard let errorSignature, !errorSignature.isEmpty else { return nil }
        return store.fixPatterns(for: errorSignature)
            .sorted { lhs, rhs in
                let lhsScore = MemoryScorer.fixPatternScore(pattern: lhs, now: now)
                let rhsScore = MemoryScorer.fixPatternScore(pattern: rhs, now: now)
                if lhsScore == rhsScore {
                    return lhs.workspaceRelativePath ?? "" < rhs.workspaceRelativePath ?? ""
                }
                return lhsScore > rhsScore
            }
            .first?
            .workspaceRelativePath
    }

    /// Command-repetition bias for a category in a workspace.
    public func commandBias(category: String?, workspaceRoot: String?) -> Double {
        guard let category, let workspaceRoot else { return 0 }
        let successes = store.commandSuccessCount(category: category, workspaceRoot: workspaceRoot)
        let failures = store.commandFailureCount(category: category, workspaceRoot: workspaceRoot)
        return MemoryScorer.commandBias(successes: successes, failures: failures)
    }
}
