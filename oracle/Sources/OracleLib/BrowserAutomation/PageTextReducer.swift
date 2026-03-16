import Foundation

// ─────────────────────────────────────────────────────────
// PageTextReducer — strip HTML to readable text (Phase 7)
//
// Follows page-agent's readability approach: remove nav,
// ads, scripts; keep main content.
// ─────────────────────────────────────────────────────────

public final class PageTextReducer {

    public init() {}

    /// Reduce raw HTML to readable plain text.
    public func reduce(html: String) -> String {
        // Phase 7: real readability parsing (swift port or sidecar call)
        var text = html
        // Strip tags (very rough)
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Collapse whitespace
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
