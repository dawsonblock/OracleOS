import Foundation

// ─────────────────────────────────────────────────────────
// CandidateGenerator — memory-first candidate generation
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// Generates action candidates for a given state using a
// strict priority order:
//
//   1. StateMemory suggestions (historically successful actions)
//   2. PlanningGraph valid actions (graph-constrained edges)
//   3. LLM fallback candidates (only when memory and graph empty)
//
// The LLM should fill gaps, not lead action selection.
// ─────────────────────────────────────────────────────────

/// Generates Candidate actions for a given state using a
/// memory-first, graph-second, LLM-last priority order.
public final class CandidateGenerator {

    private let stateMemoryIndex: StateMemoryIndex
    private let planningGraphEngine: PlanningGraphEngine

    /// Maximum candidates returned per generation cycle.
    public let maxCandidates: Int

    public init(
        stateMemoryIndex: StateMemoryIndex,
        planningGraphEngine: PlanningGraphEngine,
        maxCandidates: Int = 6
    ) {
        self.stateMemoryIndex = stateMemoryIndex
        self.planningGraphEngine = planningGraphEngine
        self.maxCandidates = maxCandidates
    }

    /// Generate candidates for the given state.
    ///
    /// - Parameters:
    ///   - stateSignature: Compressed state signature for memory lookup.
    ///   - abstractStateID: Abstract state ID for graph edge lookup.
    ///   - llmSchemas: Optional schemas from the LLM when memory and
    ///     graph cannot fully populate the candidate list.
    /// - Returns: Up to maxCandidates candidates in priority order.
    public func generate(
        stateSignature: StateSignature,
        abstractStateID: String,
        llmSchemas: [ActionSchema] = []
    ) -> [Candidate] {
        var candidates: [Candidate] = []

        // 1. Memory suggestions — historically successful actions.
        candidates += memoryCandidates(for: stateSignature)

        // 2. Graph suggestions — valid edges from the current state.
        candidates += graphCandidates(for: abstractStateID, excluding: candidates)

        // 3. LLM fallback — only when gaps remain.
        candidates += llmCandidates(from: llmSchemas, excluding: candidates)

        return Array(candidates.prefix(maxCandidates))
    }

    /// The number of candidates each source contributed in the last
    /// generation. Useful for MetricsRecorder source-distribution tracking.
    public private(set) var lastSourceCounts: [CandidateSource: Int] = [:]

    // MARK: - Private

    /// Attempt to infer the original ActionSchemaKind from a stored action name.
    private func inferKind(for actionName: String) -> ActionSchemaKind {
        let components = actionName.split(separator: "_", maxSplits: 1)
        guard let prefix = components.first else { return .custom }
        return ActionSchemaKind(rawValue: String(prefix)) ?? .custom
    }

    private func memoryCandidates(for signature: StateSignature) -> [Candidate] {
        // likelyActions returns action type names sorted by success rate
        let actionNames = stateMemoryIndex.likelyActions(for: signature)

        // Also get full stats for richer hypothesis text
        let stats = stateMemoryIndex.stats(for: signature)
        let statsByType = Dictionary(stats.map { ($0.actionType, $0) },
                                     uniquingKeysWith: { first, _ in first })

        let results = actionNames.compactMap { name -> Candidate? in
            guard !name.isEmpty else { return nil }

            let kind = inferKind(for: name)
            let stat = statsByType[name]
            let rate = stat.map { Int($0.successRate * 100) } ?? 0
            let attempts = stat?.attempts ?? 0

            return Candidate(
                hypothesis: "Historically successful (\(rate)% over \(attempts) attempts)",
                schema: ActionSchema(
                    kind: kind,
                    domain: .system,
                    name: name,
                    description: "Memory-suggested action"
                ),
                source: .memory
            )
        }

        lastSourceCounts[.memory] = results.count
        return results
    }

    private func graphCandidates(
        for stateID: String,
        excluding existing: [Candidate]
    ) -> [Candidate] {
        let existingNames = Set(existing.map(\.schema.name))
        let edges = planningGraphEngine.validActions(for: stateID)

        let results = edges
            .filter { !existingNames.contains($0.actionType) }
            .map { edge in
                Candidate(
                    hypothesis: "Graph-valid action (score \(String(format: "%.2f", edge.score)), \(edge.traversals) traversals)",
                    schema: ActionSchema(
                        kind: inferKind(for: edge.actionType),
                        domain: edge.domain,
                        name: edge.actionType,
                        description: "Graph-suggested action"
                    ),
                    source: .graph
                )
            }

        lastSourceCounts[.graph] = results.count
        return results
    }

    private func llmCandidates(
        from schemas: [ActionSchema],
        excluding existing: [Candidate]
    ) -> [Candidate] {
        let existingNames = Set(existing.map(\.schema.name))

        let results = schemas
            .filter { !existingNames.contains($0.name) }
            .map { schema in
                Candidate(
                    hypothesis: "LLM-generated fallback action",
                    schema: schema,
                    source: .llmFallback
                )
            }

        lastSourceCounts[.llmFallback] = results.count
        return results
    }
}
