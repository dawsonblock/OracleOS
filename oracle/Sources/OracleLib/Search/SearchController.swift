import Foundation

// ─────────────────────────────────────────────────────────
// SearchController — federated search gateway (Phase 14)
//
// Aggregates results from: MetaSearch sidecar, code index
// sidecar, local graph store, web extractor.
//
// Follows R4: results are returned as data, never
// autonomously executed.
// ─────────────────────────────────────────────────────────

public final class SearchController {

    private let codeQuery: CodeQueryEngine
    private let graphStore: GraphStore
    private let webExtractor: WebExtractor

    public init(codeQuery: CodeQueryEngine, graphStore: GraphStore, webExtractor: WebExtractor) {
        self.codeQuery = codeQuery
        self.graphStore = graphStore
        self.webExtractor = webExtractor
    }

    // ── Unified search ──────────────────────────────────

    public struct SearchResult {
        public let source: String      // "code" | "graph" | "web" | "metasearch"
        public let title: String
        public let snippet: String
        public let relevance: Double
    }

    public func search(query: String, limit: Int = 10) -> [SearchResult] {
        var results: [SearchResult] = []

        // 1. Local graph search — artifact + trace matches
        let traces = graphStore.recentTraces(limit: limit)
        for t in traces where t.actionType.localizedCaseInsensitiveContains(query) {
            results.append(SearchResult(
                source: "graph",
                title: "Trace: \(t.actionType)",
                snippet: "success=\(t.success) detail=\(t.detail)",
                relevance: 0.6
            ))
        }

        // 2. Code index search — stub until sidecar wired
        let codeResults = codeQuery.searchPattern(pattern: query)
        if !codeResults.isEmpty {
            results.append(SearchResult(
                source: "code",
                title: "Symbol match",
                snippet: codeResults.joined(separator: ", "),
                relevance: 0.8
            ))
        }

        // 3. Web extraction — stub
        let webResult = webExtractor.extract(url: "https://search.example.com/q=\(query)")
        if !webResult.isEmpty {
            results.append(SearchResult(
                source: "web",
                title: "Web: \(query)",
                snippet: webResult,
                relevance: 0.5
            ))
        }

        return results.sorted { $0.relevance > $1.relevance }
    }
}
