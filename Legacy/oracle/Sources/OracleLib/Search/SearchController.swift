import Foundation

// ─────────────────────────────────────────────────────────
// SearchController — federated search + candidate selection
//
// Two modes of operation:
//
//   1. Federated search (original): aggregates results from
//      code index, graph store, and web extractor.
//
//   2. Candidate-based search (new): generates candidates
//      via memory/graph/LLM, executes them, selects best.
//      This is the search-centric action selection pipeline
//      from the architecture.
//
// Follows R4: results are returned as data, never
// autonomously executed.
// ─────────────────────────────────────────────────────────

public final class SearchController {

    private let codeQuery: CodeQueryEngine
    private let graphStore: GraphStore
    private let webExtractor: WebExtractor

    // ── Candidate-based search subsystem ────────────────

    public private(set) var candidateGenerator: CandidateGenerator?
    public let resultSelector = ResultSelector()

    public init(codeQuery: CodeQueryEngine, graphStore: GraphStore, webExtractor: WebExtractor) {
        self.codeQuery = codeQuery
        self.graphStore = graphStore
        self.webExtractor = webExtractor
    }

    /// Attach the candidate generator for search-centric action selection.
    public func attachCandidateGenerator(_ generator: CandidateGenerator) {
        self.candidateGenerator = generator
    }

    // ── Candidate-based search cycle ────────────────────
    //
    // state -> generate candidates -> execute -> verify -> select best
    //
    // The evaluate closure is provided by the runtime and is
    // responsible for running each candidate through
    // VerifiedActionExecutor + CriticLoop.

    /// Run a full search cycle: generate candidates, execute and
    /// verify each one, then select the best verified result.
    ///
    /// - Parameters:
    ///   - stateSignature: Current compressed state signature.
    ///   - abstractStateID: Current abstract state for graph lookup.
    ///   - llmSchemas: Optional LLM fallback schemas.
    ///   - evaluate: Closure that executes a candidate and returns
    ///     its verified result.
    /// - Returns: The best verified CandidateResult, or nil.
    public func searchCandidates(
        stateSignature: StateSignature,
        abstractStateID: String,
        llmSchemas: [ActionSchema] = [],
        evaluate: (Candidate) -> CandidateResult?
    ) -> CandidateResult? {
        guard let generator = candidateGenerator else { return nil }

        let candidates = generator.generate(
            stateSignature: stateSignature,
            abstractStateID: abstractStateID,
            llmSchemas: llmSchemas
        )

        guard !candidates.isEmpty else { return nil }

        var results: [CandidateResult] = []
        for candidate in candidates {
            if let result = evaluate(candidate) {
                results.append(result)
                // Early exit: if we find a fully successful result
                // from memory, prefer it immediately.
                if result.success && result.candidate.source == .memory {
                    break
                }
            }
        }

        return resultSelector.selectBest(from: results)
    }

    /// Number of candidates the generator will produce per cycle.
    public var maxCandidates: Int { candidateGenerator?.maxCandidates ?? 0 }

    // ── Unified search ──────────────────────────────────

    public struct SearchResult: Equatable {
        public let source: String      // "code" | "graph" | "web" | "metasearch"
        public let title: String
        public let snippet: String
        public let url: String
        public let timestamp: Date?
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
                snippet: "success=\(t.success) stateHash=\(t.postStateHash)",
                url: "graph://trace/recent",
                timestamp: Date(),
                relevance: 0.6
            ))
        }

        // 2. Code index search
        let codeResults = codeQuery.searchPattern(pattern: query)
        if !codeResults.isEmpty {
            results.append(SearchResult(
                source: "code",
                title: "Symbol match for '\(query)'",
                snippet: codeResults.joined(separator: ", "),
                url: "code://pattern/\(query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                timestamp: Date(),
                relevance: 0.8
            ))
        }

        // 3. Web extraction
        if let webResult = webExtractor.extract(url: "https://search.example.com/q=\(query)") {
            results.append(SearchResult(
                source: "web",
                title: webResult.title,
                snippet: String(webResult.markdownBody.prefix(300)),
                url: webResult.url,
                timestamp: webResult.timestamp,
                relevance: 0.5
            ))
        }

        return results.sorted { $0.relevance > $1.relevance }
    }
}
