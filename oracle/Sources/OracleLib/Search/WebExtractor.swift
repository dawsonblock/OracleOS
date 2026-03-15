import Foundation

// ─────────────────────────────────────────────────────────
// WebExtractor — read-only web content extraction (Phase 14)
//
// Extracts text / structured data from URLs.
// Does NOT execute or navigate — browser actions go through
// BrowserController instead.
//
// Phase 14: real HTTP requests + readability parsing.
// ─────────────────────────────────────────────────────────

public final class WebExtractor {

    private let crawlerURL: String
    private let http = HTTPClient(timeout: 20)

    public struct Extraction {
        public let url: String
        public let title: String
        public let text: String
        public let timestamp: Date
    }

    public init(crawlerURL: String = "http://localhost:8083") {
        self.crawlerURL = crawlerURL
    }

    /// Extract readable text from a URL via crawler sidecar.
    public func extract(url: String) -> String {
        print("[web-extractor] Fetching: \(url)")
        let response = http.post(
            url: "\(crawlerURL)/extract",
            json: ["url": url]
        )
        guard response.success, let json = response.json else {
            print("[web-extractor] Crawler unreachable: \(response.error ?? "unknown")")
            return ""
        }
        return json["content"] as? String ?? ""
    }

    /// Extract structured data (title + body + timestamp).
    public func extractStructured(url: String) -> Extraction? {
        let text = extract(url: url)
        guard !text.isEmpty else { return nil }
        return Extraction(url: url, title: url, text: text, timestamp: Date())
    }

    /// Batch extract from multiple URLs via crawler sidecar.
    public func extractBatch(urls: [String]) -> [Extraction] {
        let response = http.post(
            url: "\(crawlerURL)/batch",
            json: ["urls": urls]
        )
        guard response.success, let json = response.json,
              let results = json["results"] as? [[String: Any]] else {
            return []
        }
        return results.compactMap { r in
            guard let content = r["content"] as? String, !content.isEmpty,
                  let u = r["url"] as? String else { return nil }
            return Extraction(url: u, title: u, text: content, timestamp: Date())
        }
    }

    public func isAvailable() -> Bool {
        return http.isReachable(baseURL: crawlerURL)
    }
}
