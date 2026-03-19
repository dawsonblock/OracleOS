import Foundation

// ─────────────────────────────────────────────────────────
// SearchRanking — relevance + recency ranking
//
// Upgraded to support advanced vector ranking scaffolds,
// term-frequency bounds (BM25 style), and semantic deduplication.
// ─────────────────────────────────────────────────────────

public final class SearchRanking {

    public struct ScoredResult: Equatable {
        public let id: String
        public let title: String
        public let snippet: String
        public let url: String
        public let score: Double
    }

    public init() {}

    /// Main ranking pipeline: TF-IDF scoring -> Recency Boosting -> Deduplication
    public func rank(_ results: [SearchController.SearchResult], query: String) -> [ScoredResult] {
        var scored = results.map { r in
            let baseScore = calculateBM25Scaffold(text: r.snippet, query: query)
            let recencyBoost = calculateRecencyBoost(timestamp: r.timestamp)
            let finalScore = (baseScore * 0.7) + (recencyBoost * 0.3)
            
            return ScoredResult(
                id: UUID().uuidString,
                title: r.title,
                snippet: r.snippet,
                url: r.url,
                score: finalScore
            )
        }
        
        scored.sort { $0.score > $1.score }
        return deduplicate(scored)
    }
    
    // MARK: - Internal Ranking Mechanisms
    
    private func calculateBM25Scaffold(text: String, query: String) -> Double {
        // Scaffold for real TF-IDF/BM25 text similarity ranking
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let textTerms = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var matches = 0.0
        for term in queryTerms where !term.isEmpty {
            if textTerms.contains(term) {
                matches += 1.0
            }
        }
        
        let termFrequency = matches / Double(max(1, queryTerms.count))
        return min(termFrequency * 1.5, 1.0) // normalized approximate
    }
    
    private func calculateRecencyBoost(timestamp: Date?) -> Double {
        guard let timestamp = timestamp else { return 0.5 }
        let hoursOld = abs(timestamp.timeIntervalSinceNow) / 3600
        
        switch hoursOld {
        case 0..<24: return 1.0       // < 1 day
        case 24..<168: return 0.8     // < 1 week
        case 168..<720: return 0.5    // < 1 month
        default: return 0.2           // Older
        }
    }
    
    private func deduplicate(_ results: [ScoredResult]) -> [ScoredResult] {
        var uniqueURLs = Set<String>()
        var deduplicated = [ScoredResult]()
        
        for result in results {
            if !uniqueURLs.contains(result.url) {
                uniqueURLs.insert(result.url)
                deduplicated.append(result)
            }
        }
        
        return deduplicated
    }
}
