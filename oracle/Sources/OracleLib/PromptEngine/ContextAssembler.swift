import Foundation

// ─────────────────────────────────────────────────────────
// ContextAssembler — build the prompt context window (Phase 6)
//
// Gathers: goal, recent traces, graph context, code symbols,
// observation snapshot, active plan, memory excerpts.
//
// Enforces a token budget so prompts stay bounded.
// ─────────────────────────────────────────────────────────

public final class ContextAssembler {

    private let graphStore: GraphStore
    private let codeQuery: CodeQueryEngine
    private let retriever: ContextRetriever
    private let tokenBudget: TokenBudgetManager

    public init(
        graphStore: GraphStore,
        codeQuery: CodeQueryEngine,
        retriever: ContextRetriever,
        tokenBudget: TokenBudgetManager = TokenBudgetManager()
    ) {
        self.graphStore = graphStore
        self.codeQuery = codeQuery
        self.retriever = retriever
        self.tokenBudget = tokenBudget
    }

    // ── Assemble full context string ────────────────────

    public struct AssembledContext {
        public let text: String
        public let estimatedTokens: Int
        public let sections: [String]

        public init(text: String, estimatedTokens: Int, sections: [String]) {
            self.text = text
            self.estimatedTokens = estimatedTokens
            self.sections = sections
        }
    }

    public func assemble(goal: Goal, plan: Plan?) -> AssembledContext {
        var sections: [String] = []

        // 1. Goal description
        sections.append("## Goal\n\(goal.description)")

        // 2. Active plan summary
        if let p = plan {
            let steps = p.actions.map { "- \($0.type): \($0.parameters)" }.joined(separator: "\n")
            sections.append("## Plan\nConfidence: \(p.confidence)\n\(steps)")
        }

        // 3. Recent traces
        let traces = graphStore.recentTraces(limit: 5)
        if !traces.isEmpty {
            let traceText = traces.map { "  \($0.actionType) → \($0.success ? "✓" : "✗")" }
                .joined(separator: "\n")
            sections.append("## Recent Trace\n\(traceText)")
        }

        // 4. Retrieved memory excerpts
        let memories = retriever.retrieve(query: goal.description, limit: 3)
        if !memories.isEmpty {
            sections.append("## Memory\n\(memories.joined(separator: "\n"))")
        }

        let text = sections.joined(separator: "\n\n")
        let estimated = tokenBudget.estimate(text: text)

        return AssembledContext(text: text, estimatedTokens: estimated, sections: sections)
    }
}
