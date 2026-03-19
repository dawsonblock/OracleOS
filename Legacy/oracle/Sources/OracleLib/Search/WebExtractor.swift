import Foundation

// ─────────────────────────────────────────────────────────
// WebExtractor — Active Web Context Bridge
//
// Extracts text / structured data from URLs.
// Expanded to support Safari Automation Bridge and Headless
// Playwright scraping through JS injection routes.
// ─────────────────────────────────────────────────────────

public enum ExtractionEngine {
    case sidecar(url: URL)
    case safariLocal
}

public struct ExtractedPage: Equatable {
    public let url: String
    public let title: String
    public let markdownBody: String
    public let timestamp: Date
}

public final class WebExtractor {

    private let engine: ExtractionEngine
    private let http = HTTPClient(timeout: 20)

    public init(engine: ExtractionEngine = .sidecar(url: URL(string: "http://localhost:8083")!)) {
        self.engine = engine
    }

    /// Extract readable markdown from a URL
    public func extract(url: String) -> ExtractedPage? {
        switch engine {
        case .sidecar(let activeURL):
            return extractViaSidecar(url: url, endpoint: activeURL)
        case .safariLocal:
            return extractViaSafariBridge(url: url)
        }
    }

    // MARK: - Sidecar (Playwright/Scraper) Logic
    
    private func extractViaSidecar(url: String, endpoint: URL) -> ExtractedPage? {
        print("[web-extractor] Fetching via Sidecar: \(url)")
        let reqURL = endpoint.appendingPathComponent("extract").absoluteString
        let response = http.post(url: reqURL, json: ["url": url])
        
        guard response.success, let json = response.json,
              let content = json["content"] as? String else {
            return nil
        }
        
        let title = json["title"] as? String ?? url
        return ExtractedPage(url: url, title: title, markdownBody: content, timestamp: Date())
    }

    // MARK: - Native Safari Injection Logic
    
    private func extractViaSafariBridge(url: String) -> ExtractedPage? {
        // Scaffold for OSA/AppleScript JavaScript execution targeting Safari
        // Tells Safari to open background tab, inject Readability.js, and return outerHTML
        print("[web-extractor] Native Safari JS Injection requested for \(url)")
        
        let applescript = """
        tell application "Safari"
            -- Navigation and JS injection scaffold
            do JavaScript "document.body.innerText" in document 1
        end tell
        """
        
        // TODO: Map to NSAppleScript execution securely
        return ExtractedPage(
            url: url,
            title: "Safari Bridge Scaffold",
            markdownBody: "Scaffold: Run Readability.js against \(url) natively via AppleEvents",
            timestamp: Date()
        )
    }

    /// Batch extract from multiple URLs
    public func extractBatch(urls: [String]) -> [ExtractedPage] {
        return urls.compactMap { extract(url: $0) }
    }
}
