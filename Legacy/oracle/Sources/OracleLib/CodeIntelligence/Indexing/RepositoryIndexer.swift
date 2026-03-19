import Foundation

// ─────────────────────────────────────────────────────────
// Code Intelligence — Indexing Layer
//
// RepositoryIndexer builds local code index.
// SymbolGraph, CallGraph, DependencyGraph are views
// over the canonical ProgramKnowledgeGraph (R8).
//
// Phase 10: local indexing
// Phase 11: cocoindex sidecar upgrade
// ─────────────────────────────────────────────────────────

public final class RepositoryIndexer {

    public init() {}

    public func index(repoPath: String) -> IndexResult {
        // Phase 10: walk files, parse symbols
        print("[codeindex] Indexing: \(repoPath)")
        return IndexResult(fileCount: 0, symbolCount: 0)
    }

    public struct IndexResult {
        public let fileCount: Int
        public let symbolCount: Int
    }
}

public final class SymbolGraph {

    public init() {}

    public func lookupDefinition(symbol: String) -> String? {
        return nil
    }

    public func symbolsInFile(path: String) -> [String] {
        return []
    }
}

public final class CallGraph {

    public init() {}

    public func callers(of symbol: String) -> [String] {
        return []
    }

    public func callees(of symbol: String) -> [String] {
        return []
    }
}

public final class DependencyGraph {

    public init() {}

    public func dependenciesOf(file: String) -> [String] {
        return []
    }

    public func dependentsOf(file: String) -> [String] {
        return []
    }
}
