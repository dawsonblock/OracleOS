import Foundation

// ─────────────────────────────────────────────────────────
// DOMIndexer — index DOM elements for fast lookup (Phase 7)
// ─────────────────────────────────────────────────────────

public final class DOMIndexer {

    public struct DOMElement {
        public let id: String
        public let tag: String
        public let text: String
        public let attributes: [String: String]
    }

    private var elements: [DOMElement] = []

    public init() {}

    public func index(html: String) {
        // Phase 7: parse HTML → element list
        elements = []
    }

    public func find(selector: String) -> DOMElement? {
        return elements.first { $0.id == selector || $0.tag == selector }
    }

    public func allInteractive() -> [DOMElement] {
        return elements.filter { ["a", "button", "input", "select", "textarea"].contains($0.tag) }
    }
}
