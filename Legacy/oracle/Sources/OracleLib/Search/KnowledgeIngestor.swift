import Foundation

// ─────────────────────────────────────────────────────────
// KnowledgeIngestor — feed external knowledge into graph (Phase 14)
//
// Sources: documentation, web pages, RSS, manuals.
// Writes: GraphStore nodes of type "knowledge".
// ─────────────────────────────────────────────────────────

public final class KnowledgeIngestor {

    private let graphStore: GraphStore

    public init(graphStore: GraphStore) {
        self.graphStore = graphStore
    }

    public func ingest(title: String, body: String, source: String) {
        let id = graphStore.addNode(type: "knowledge", label: title, data: body)
        print("[knowledge] Ingested \(id): \(title) from \(source)")
    }
}
