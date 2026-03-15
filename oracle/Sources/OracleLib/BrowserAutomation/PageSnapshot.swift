import Foundation

// ─────────────────────────────────────────────────────────
// PageSnapshot — immutable snapshot of a browser page (Phase 7)
// ─────────────────────────────────────────────────────────

public struct PageSnapshot {
    public let url: String
    public let html: String
    public let timestamp: Date

    public init(url: String, html: String, timestamp: Date) {
        self.url = url
        self.html = html
        self.timestamp = timestamp
    }
}
