import Foundation

// ─────────────────────────────────────────────────────────
// PromptCache — LRU cache for prompt results (Phase 6)
//
// Avoids re-running identical prompts within a session.
// Keys are hash(prompt) → cached response.
// ─────────────────────────────────────────────────────────

public final class PromptCache {

    private var cache: [Int: CachedEntry] = [:]
    private let maxEntries: Int

    public struct CachedEntry {
        public let response: String
        public let timestamp: Date
    }

    public init(maxEntries: Int = 64) {
        self.maxEntries = maxEntries
    }

    public func get(prompt: String) -> String? {
        let key = prompt.hashValue
        return cache[key]?.response
    }

    public func set(prompt: String, response: String) {
        let key = prompt.hashValue
        if cache.count >= maxEntries {
            // Evict oldest
            if let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp }) {
                cache.removeValue(forKey: oldest.key)
            }
        }
        cache[key] = CachedEntry(response: response, timestamp: Date())
    }
}
