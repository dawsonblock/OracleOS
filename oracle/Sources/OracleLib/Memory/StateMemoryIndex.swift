import Foundation

// ─────────────────────────────────────────────────────────
// StateMemoryIndex — compressed state caching and reuse
//
// Indexes compressed UI/system states by signature and
// tracks action statistics (attempts, successes) per state.
// Provides the planner with previously successful strategies
// when a familiar state is encountered, reducing exploration.
//
// Evicts oldest entries when capacity is exceeded.
//
// Architecture rule (R2): This is part of the Workflow
// memory category — reusable successful patterns.
// ─────────────────────────────────────────────────────────

/// Signature identifying a compressed state.
/// Composed from the current context (app, elements, hashes).
public struct StateSignature: Hashable {
    public let hash: String

    public init(hash: String) {
        self.hash = hash
    }

    /// Create a signature from component parts.
    public static func from(context: String, actionTypes: [String] = []) -> StateSignature {
        var hasher = Hasher()
        hasher.combine(context)
        for t in actionTypes { hasher.combine(t) }
        let hash = String(abs(hasher.finalize()))
        return StateSignature(hash: hash)
    }
}

/// Statistics for one action type at a specific state.
public struct ActionStatistics {
    public let actionType: String
    public var attempts: Int = 0
    public var successes: Int = 0
    public var lastAttempt: Date

    public init(actionType: String) {
        self.actionType = actionType
        self.lastAttempt = Date()
    }

    public var successRate: Double {
        guard attempts > 0 else { return 0 }
        return Double(successes) / Double(attempts)
    }
}

/// A state entry in the memory index.
public struct StateEntry {
    public let signature: StateSignature
    public var actionStats: [String: ActionStatistics]  // actionType -> stats
    public let createdAt: Date
    public var lastAccessedAt: Date

    public init(signature: StateSignature) {
        self.signature = signature
        self.actionStats = [:]
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
}

/// StateMemoryIndex caches known states and their action outcomes.
public final class StateMemoryIndex {

    /// Maximum entries before eviction
    public static let maxEntries = 500

    /// Minimum success rate for an action to be considered "likely"
    public static let likelyThreshold = 0.6

    /// Minimum attempts before an action is eligible as "likely"
    public static let minAttempts = 2

    /// State entries keyed by signature hash
    private var entries: [String: StateEntry] = [:]

    public init() {}

    // ── Recording ───────────────────────────────────────

    /// Record an action outcome for a given state.
    public func record(
        stateSignature: StateSignature,
        actionType: String,
        success: Bool
    ) {
        // Create entry if needed
        if entries[stateSignature.hash] == nil {
            entries[stateSignature.hash] = StateEntry(signature: stateSignature)
            evictIfNeeded()
        }

        var entry = entries[stateSignature.hash]!
        entry.lastAccessedAt = Date()

        // Update action stats
        if entry.actionStats[actionType] == nil {
            entry.actionStats[actionType] = ActionStatistics(actionType: actionType)
        }
        entry.actionStats[actionType]!.attempts += 1
        if success {
            entry.actionStats[actionType]!.successes += 1
        }
        entry.actionStats[actionType]!.lastAttempt = Date()

        entries[stateSignature.hash] = entry
    }

    // ── Queries ─────────────────────────────────────────

    /// Get action statistics for a state.
    public func stats(for signature: StateSignature) -> [ActionStatistics] {
        guard var entry = entries[signature.hash] else { return [] }
        entry.lastAccessedAt = Date()
        entries[signature.hash] = entry
        return Array(entry.actionStats.values)
    }

    /// Get likely successful actions for a state,
    /// sorted by success rate descending.
    public func likelyActions(for signature: StateSignature) -> [String] {
        let allStats = stats(for: signature)
        return allStats
            .filter { $0.attempts >= StateMemoryIndex.minAttempts
                   && $0.successRate >= StateMemoryIndex.likelyThreshold }
            .sorted { $0.successRate > $1.successRate }
            .map { $0.actionType }
    }

    /// Check if we have any memory for this state.
    public func hasMemory(for signature: StateSignature) -> Bool {
        return entries[signature.hash] != nil
    }

    /// Success rate for a specific action at a specific state.
    public func successRate(
        for signature: StateSignature,
        actionType: String
    ) -> Double? {
        guard let entry = entries[signature.hash],
              let stat = entry.actionStats[actionType],
              stat.attempts > 0 else {
            return nil
        }
        return stat.successRate
    }

    /// Total number of indexed states.
    public var stateCount: Int {
        return entries.count
    }

    // ── Eviction ────────────────────────────────────────

    /// Evict oldest entries if capacity exceeded.
    private func evictIfNeeded() {
        guard entries.count > StateMemoryIndex.maxEntries else { return }

        // Sort by lastAccessedAt ascending (oldest first)
        let sorted = entries.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }

        // Remove oldest 10%
        let removeCount = entries.count / 10
        for (key, _) in sorted.prefix(removeCount) {
            entries.removeValue(forKey: key)
        }

        print("[stateMemory] Evicted \(removeCount) entries (\(entries.count) remaining)")
    }

    /// Reset all state memory.
    public func reset() {
        entries.removeAll()
    }
}
