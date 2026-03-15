import Foundation

// ─────────────────────────────────────────────────────────
// Code Intelligence — Query Layer
//
// CodeQueryEngine connects to:
//   • Local SymbolGraph (Phase 10)
//   • cocoindex sidecar (Phase 11)
//
// Provides: symbol lookup, reference search, pattern search
// ─────────────────────────────────────────────────────────

public final class CodeQueryEngine {

    private let sidecarURL: String
    private let http = HTTPClient(timeout: 10)

    public init(sidecarURL: String = "http://localhost:8081") {
        self.sidecarURL = sidecarURL
    }

    public func lookupSymbol(name: String) -> [String] {
        let resp = http.post(url: "\(sidecarURL)/symbol_lookup", json: ["symbol": name])
        guard resp.success, let json = resp.json,
              let locations = json["locations"] as? [[String: Any]] else { return [] }
        return locations.compactMap { loc in
            guard let file = loc["file"] as? String, let line = loc["line"] as? Int else { return nil }
            return "\(file):\(line)"
        }
    }

    public func findReferences(symbol: String) -> [String] {
        let resp = http.post(url: "\(sidecarURL)/reference_lookup", json: ["symbol": symbol])
        guard resp.success, let json = resp.json,
              let refs = json["references"] as? [[String: Any]] else { return [] }
        return refs.compactMap { ref in
            guard let file = ref["file"] as? String, let line = ref["line"] as? Int else { return nil }
            return "\(file):\(line)"
        }
    }

    public func searchPattern(pattern: String) -> [String] {
        let resp = http.post(url: "\(sidecarURL)/text_search", json: ["pattern": pattern])
        guard resp.success, let json = resp.json,
              let results = json["results"] as? [[String: Any]] else { return [] }
        return results.compactMap { r in
            guard let file = r["file"] as? String, let line = r["line"] as? Int else { return nil }
            return "\(file):\(line)"
        }
    }

    public func indexRepository(path: String) -> (files: Int, symbols: Int) {
        let resp = http.post(url: "\(sidecarURL)/index", json: ["path": path])
        guard resp.success, let json = resp.json else { return (0, 0) }
        let files = json["indexed_files"] as? Int ?? 0
        let symbols = json["symbols"] as? Int ?? 0
        return (files, symbols)
    }

    public func isAvailable() -> Bool {
        return http.isReachable(baseURL: sidecarURL)
    }
}

public final class SymbolLookup {

    public init() {}

    public func lookup(name: String) -> String? {
        return nil
    }
}

public final class ReferenceFinder {

    public init() {}

    public func find(symbol: String) -> [String] {
        return []
    }
}
