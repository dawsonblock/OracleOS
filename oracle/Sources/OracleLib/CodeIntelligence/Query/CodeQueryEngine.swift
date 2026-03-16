import Foundation

// ─────────────────────────────────────────────────────────
// Code Intelligence — Query Layer
//
// CodeQueryEngine routes complex search queries between:
//   • Local Indexing (SymbolGraph)
//   • Remote/Sidecar Indexing (cocoindex)
//
// Provides robust, schema-driven architectural search.
// ─────────────────────────────────────────────────────────

public final class CodeQueryEngine {

    private let sidecarURL: String
    private let http = HTTPClient(timeout: 10)
    private let localGraph: SymbolGraph
    public var routingStrategy: QueryRoutingStrategy

    public init(
        localGraph: SymbolGraph = SymbolGraph(),
        sidecarURL: String = "http://localhost:8081",
        routingStrategy: QueryRoutingStrategy = .auto
    ) {
        self.localGraph = localGraph
        self.sidecarURL = sidecarURL
        self.routingStrategy = routingStrategy
    }

    public func execute(query: GraphSearchQuery) -> [GraphSearchResult] {
        switch routingStrategy {
        case .local:
            return executeLocal(query: query)
        case .sidecar:
            return executeSidecar(query: query)
        case .auto:
            if isSidecarAvailable() {
                return executeSidecar(query: query)
            } else {
                return executeLocal(query: query)
            }
        }
    }

    private func executeLocal(query: GraphSearchQuery) -> [GraphSearchResult] {
        guard let defs = localGraph.lookupDefinition(symbol: query.symbol) else { return [] }
        // Very basic stub to link SymbolGraph with correct schema representation
        return [GraphSearchResult(file: defs, line: 1)]
    }

    private func executeSidecar(query: GraphSearchQuery) -> [GraphSearchResult] {
        let payload: [String: Any] = [
            "symbol": query.symbol,
            "kind": String(describing: query.kind)
        ]
        
        // This relies on the updated sidecar routing APIs
        let resp = http.post(url: "\(sidecarURL)/symbol_lookup", json: payload)
        guard resp.success, let json = resp.json,
              let locations = json["locations"] as? [[String: Any]] else { return [] }
              
        return locations.compactMap { loc in
            guard let file = loc["file"] as? String, 
                  let line = loc["line"] as? Int else { return nil }
            let snippet = loc["snippet"] as? String
            return GraphSearchResult(file: file, line: line, contextSnippet: snippet)
        }
    }

    public func isSidecarAvailable() -> Bool {
        return http.isReachable(baseURL: sidecarURL)
    }
    
    public func indexRepository(path: String) -> (files: Int, symbols: Int) {
        let resp = http.post(url: "\(sidecarURL)/index", json: ["path": path])
        guard resp.success, let json = resp.json else { return (0, 0) }
        let files = json["indexed_files"] as? Int ?? 0
        let symbols = json["symbols"] as? Int ?? 0
        return (files, symbols)
    }
    
    // Legacy wrappers needed for compilation stability during refactor
    public func lookupSymbol(name: String) -> [String] {
        let results = execute(query: GraphSearchQuery(symbol: name, kind: .any, scope: .global))
        return results.map { "\($0.file):\($0.line)" }
    }
    
    public func findReferences(symbol: String) -> [String] {
        // Just stub for backward compat until ContextAssembler is migrated
        return []
    }
    
    public func searchPattern(pattern: String) -> [String] {
        // Just stub for backward compat until ContextAssembler is migrated
        return []
    }
}

public final class SymbolLookup {
    public init() {}
    public func lookup(name: String) -> String? { return nil }
}

public final class ReferenceFinder {
    public init() {}
    public func find(symbol: String) -> [String] { return [] }
}
