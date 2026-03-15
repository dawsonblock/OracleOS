import Foundation

// ─────────────────────────────────────────────────────────
// SearchRanking — relevance + recency ranking (Phase 14)
// ─────────────────────────────────────────────────────────

public final class SearchRanking {

    public struct ScoredResult {
        public let title: String
        public let snippet: String
        public let score: Double
    }

    public init() {}

    /// Re-rank a set of search results by combined score.
    public func rank(_ results: [SearchController.SearchResult]) -> [ScoredResult] {
        return results.map { r in
            ScoredResult(title: r.title, snippet: r.snippet, score: r.relevance)
        }.sorted { $0.score > $1.score }
    }
}
